alter table public.order_confirmation_tokens
  alter column user_id drop not null,
  add column if not exists phone text not null default '';

create table if not exists public.guest_order_otps (
  id uuid primary key,
  phone text not null,
  otp text not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists guest_order_otps_expires_at_idx
  on public.guest_order_otps (expires_at);

alter table public.guest_order_otps enable row level security;
revoke all on public.guest_order_otps from anon, authenticated;
grant all on public.guest_order_otps to service_role;

create or replace function public.create_order_with_stock(
  p_order jsonb,
  p_stock_items jsonb,
  p_idempotency_key text,
  p_confirmation_token_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_order public.orders;
  v_user_id uuid;
  v_payment_method text;
  v_inserted_id uuid;
begin
  v_user_id := nullif(p_order->>'user_id', '')::uuid;
  v_payment_method := p_order->>'payment_method';
  if p_idempotency_key is null or length(p_idempotency_key) > 128 then
    raise exception 'Invalid order request';
  end if;
  if v_payment_method not in ('cod', 'online') then
    raise exception 'Invalid order request';
  end if;
  if (v_payment_method = 'cod' and
      (p_confirmation_token_id is null or p_idempotency_key <> p_confirmation_token_id::text)) or
     (v_payment_method = 'online' and p_confirmation_token_id is not null) then
    raise exception 'Invalid order confirmation';
  end if;

  select * into v_order
    from public.orders
    where idempotency_key = p_idempotency_key;
  if found then
    if v_order.user_id is distinct from v_user_id then
      raise exception 'Idempotency key belongs to another user';
    end if;
    return jsonb_build_object('order', to_jsonb(v_order), 'created', false);
  end if;

  begin
    if p_confirmation_token_id is not null then
      update public.order_confirmation_tokens
        set consumed_at = now()
        where id = p_confirmation_token_id
          and user_id is not distinct from v_user_id
          and expires_at > now()
          and consumed_at is null
          and (
            phone = coalesce(p_order #>> '{delivery,phone}', '') or
            (phone = '' and v_user_id is not null)
          );
      if not found then
        select * into v_order
          from public.orders
          where idempotency_key = p_idempotency_key;
        if found and v_order.user_id is not distinct from v_user_id then
          return jsonb_build_object('order', to_jsonb(v_order), 'created', false);
        end if;
        raise exception 'Invalid or expired order confirmation';
      end if;
    end if;

    perform public.reserve_order_stock(p_stock_items);

    insert into public.orders (
      user_id, user_name, user_email, items, total, payment_method,
      reference_id, delivery, status, status_history, attribution,
      marketing_consent, idempotency_key, stock_reserved
    ) values (
      v_user_id,
      coalesce(p_order->>'user_name', ''),
      coalesce(p_order->>'user_email', ''),
      coalesce(p_order->'items', '[]'::jsonb),
      (p_order->>'total')::numeric,
      v_payment_method,
      nullif(p_order->>'reference_id', ''),
      coalesce(p_order->'delivery', '{}'::jsonb),
      coalesce(p_order->>'status', 'Pending'),
      coalesce(p_order->'status_history', '[]'::jsonb),
      coalesce(p_order->'attribution', '{}'::jsonb),
      coalesce((p_order->>'marketing_consent')::boolean, false),
      p_idempotency_key,
      true
    )
    returning id into v_inserted_id;
  exception when unique_violation then
    select * into v_order
      from public.orders
      where idempotency_key = p_idempotency_key;
    if found and v_order.user_id is not distinct from v_user_id then
      return jsonb_build_object('order', to_jsonb(v_order), 'created', false);
    end if;
    raise;
  end;

  select * into v_order from public.orders where id = v_inserted_id;
  return jsonb_build_object('order', to_jsonb(v_order), 'created', true);
end;
$$;

revoke all on function public.create_order_with_stock(jsonb, jsonb, text, uuid)
  from public, anon, authenticated;
grant execute on function public.create_order_with_stock(jsonb, jsonb, text, uuid)
  to service_role;
