-- VELQRA complete Supabase schema.
-- Run this once in the Supabase SQL Editor. Existing tables are preserved.

create extension if not exists pgcrypto;

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  name text not null default '',
  email text not null,
  phone text unique,
  password text not null,
  role text not null default 'user',
  is_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists users_email_lower_unique_idx
  on public.users (lower(email));

create table if not exists public.admins (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  password text not null,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists admins_email_lower_unique_idx
  on public.admins (lower(email));

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  price numeric(12, 2) not null check (price >= 0),
  original_price numeric(12, 2) not null default 0 check (original_price >= 0),
  discount_percent numeric(5, 2) not null default 0 check (discount_percent between 0 and 100),
  category text not null default 'Face Wash',
  stock integer not null default 0 check (stock >= 0),
  description text not null default '',
  icon text not null default '📦',
  image text not null default '',
  image_url text not null default '',
  images jsonb not null default '[]'::jsonb,
  brand text not null default '',
  weight text,
  color text not null default '',
  size text not null default '',
  material text not null default '',
  warranty text not null default '',
  tags jsonb not null default '[]'::jsonb,
  rating numeric(3, 2) not null default 0 check (rating between 0 and 5),
  reviews_count integer not null default 0 check (reviews_count >= 0),
  popularity integer not null default 0,
  promo_code text not null default '',
  promo_discount numeric(5, 2) not null default 0 check (promo_discount between 0 and 100),
  is_active boolean not null default true,
  video_url text,
  video_type text not null default 'youtube',
  attributes jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.products
  add column if not exists video_url text,
  add column if not exists video_type text not null default 'youtube',
  add column if not exists attributes jsonb not null default '{}'::jsonb;

create index if not exists products_category_idx on public.products (category);
create index if not exists products_created_at_idx on public.products (created_at desc);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users (id) on delete set null,
  user_name text not null default '',
  user_email text not null default '',
  items jsonb not null default '[]'::jsonb,
  total numeric(12, 2) not null check (total >= 0),
  payment_method text not null default 'cod',
  reference_id text,
  delivery jsonb not null default '{}'::jsonb,
  status text not null default 'Pending',
  status_history jsonb not null default '[]'::jsonb,
  attribution jsonb not null default '{}'::jsonb,
  marketing_consent boolean not null default false,
  idempotency_key text,
  stock_reserved boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists orders_idempotency_key_unique_idx
  on public.orders (idempotency_key)
  where idempotency_key is not null;
create unique index if not exists orders_reference_id_unique_idx
  on public.orders (reference_id)
  where reference_id is not null;
create index if not exists orders_user_created_at_idx
  on public.orders (user_id, created_at desc);
create index if not exists orders_status_created_at_idx
  on public.orders (status, created_at desc);

create table if not exists public.carts (
  user_id uuid primary key references public.users (id) on delete cascade,
  items jsonb not null default '[]'::jsonb,
  total_items integer not null default 0 check (total_items >= 0),
  total_price numeric(12, 2) not null default 0 check (total_price >= 0),
  total_savings numeric(12, 2) not null default 0 check (total_savings >= 0),
  updated_at timestamptz not null default now()
);

-- Keep this relationship aligned with the application's public.users table.
alter table public.carts
  drop constraint if exists carts_user_id_fkey;
alter table public.carts
  add constraint carts_user_id_fkey
  foreign key (user_id)
  references public.users (id)
  on delete cascade
  not valid;

create table if not exists public.registration_otps (
  email text primary key,
  otp text not null,
  expires_at timestamptz not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on column public.registration_otps.email is
  'Legacy column name; the registration flow stores the normalized phone number here.';

create table if not exists public.password_resets (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  otp text not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_otps (
  user_id uuid primary key references public.users (id) on delete cascade,
  email text not null default '',
  phone text not null default '',
  otp text not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists public.order_confirmation_tokens (
  id uuid primary key,
  user_id uuid references public.users (id) on delete cascade,
  phone text not null default '',
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.guest_order_otps (
  id uuid primary key,
  phone text not null,
  otp text not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists public.bank_details (
  user_id uuid primary key references public.users (id) on delete cascade,
  account_holder_name text not null,
  account_number text not null,
  ifsc_code text not null,
  bank_name text not null,
  upi_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.product_reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  user_name text not null default '',
  user_email text not null default '',
  order_id uuid references public.orders (id) on delete set null,
  rating smallint not null check (rating between 1 and 5),
  review_text text not null default '',
  image_url text,
  image_path text,
  video_url text,
  video_path text,
  is_verified_purchase boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.product_reviews
  add column if not exists image_url text,
  add column if not exists image_path text;

create index if not exists product_reviews_product_created_at_idx
  on public.product_reviews (product_id, created_at desc, id desc);

create table if not exists public.return_requests (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  items jsonb not null default '[]'::jsonb,
  reason text not null,
  description text not null default '',
  bank_details_snapshot jsonb not null default '{}'::jsonb,
  payment_transaction_id text,
  refund_amount numeric(12, 2) not null default 0 check (refund_amount >= 0),
  status text not null default 'Pending',
  status_history jsonb not null default '[]'::jsonb,
  admin_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.return_requests
  add column if not exists payment_transaction_id text;

create index if not exists return_requests_user_created_at_idx
  on public.return_requests (user_id, created_at desc);
create index if not exists return_requests_status_created_at_idx
  on public.return_requests (status, created_at desc);

create table if not exists public.return_otps (
  user_id uuid primary key references public.users (id) on delete cascade,
  order_id uuid not null references public.orders (id) on delete cascade,
  otp text not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

-- Supports databases that already had orders before campaign attribution was added.
alter table public.orders
  add column if not exists attribution jsonb not null default '{}'::jsonb,
  add column if not exists marketing_consent boolean not null default false,
  add column if not exists idempotency_key text,
  add column if not exists stock_reserved boolean not null default false;

-- Guest checkout may confirm an order without a registered user account.
alter table public.order_confirmation_tokens
  alter column user_id drop not null,
  add column if not exists phone text not null default '';

create index if not exists guest_order_otps_expires_at_idx
  on public.guest_order_otps (expires_at);

-- The backend uses the Supabase service-role key. Direct clients may only read active products.
alter table public.users enable row level security;
alter table public.admins enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.carts enable row level security;
alter table public.registration_otps enable row level security;
alter table public.password_resets enable row level security;
alter table public.order_otps enable row level security;
alter table public.order_confirmation_tokens enable row level security;
alter table public.guest_order_otps enable row level security;
alter table public.bank_details enable row level security;
alter table public.product_reviews enable row level security;
alter table public.return_requests enable row level security;
alter table public.return_otps enable row level security;

revoke insert, update, delete on public.products from anon, authenticated;
grant select on public.products to anon, authenticated;
revoke all on public.order_confirmation_tokens from anon, authenticated;
grant all on public.order_confirmation_tokens to service_role;
revoke all on public.guest_order_otps from anon, authenticated;
grant all on public.guest_order_otps to service_role;

drop policy if exists products_public_read on public.products;
create policy products_public_read
  on public.products
  for select
  to anon, authenticated
  using (is_active = true);

-- The API uses the service-role key; only active products are public to clients.
revoke all on public.users, public.admins, public.orders, public.carts,
  public.registration_otps, public.password_resets, public.order_otps,
  public.order_confirmation_tokens, public.guest_order_otps, public.bank_details,
  public.product_reviews, public.return_requests, public.return_otps
  from anon, authenticated;
grant all on public.users, public.admins, public.products, public.orders, public.carts,
  public.registration_otps, public.password_resets, public.order_otps,
  public.order_confirmation_tokens, public.guest_order_otps, public.bank_details,
  public.product_reviews, public.return_requests, public.return_otps
  to service_role;

-- These public buckets are also created lazily by the API on upload.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('product-images', 'product-images', true, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('product-videos', 'product-videos', true, 52428800, array['video/mp4', 'video/webm', 'video/quicktime', 'video/ogg'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Required by the backend's atomic order, inventory and PayU flows.
create or replace function public.reserve_order_stock(p_items jsonb)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_item record;
begin
  if p_items is null or jsonb_typeof(p_items) is distinct from 'array' or
     jsonb_array_length(p_items) = 0 then
    raise exception 'Invalid stock reservation item';
  end if;

  for v_item in
    select product_id, sum(qty)::integer as qty
    from jsonb_to_recordset(p_items) as requested(product_id uuid, qty integer)
    group by product_id
    order by product_id
  loop
    if v_item.product_id is null or v_item.qty is null or v_item.qty < 1 then
      raise exception 'Invalid stock reservation item';
    end if;

    update public.products
      set stock = stock - v_item.qty,
          updated_at = now()
      where id = v_item.product_id
        and is_active = true
        and stock >= v_item.qty;
    if not found then
      raise exception 'Insufficient stock';
    end if;
  end loop;
end;
$$;

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

create or replace function public.confirm_order_payment(
  p_order_id uuid,
  p_reference_id text,
  p_mihpayid text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_order public.orders;
  v_history jsonb;
  v_paid boolean;
begin
  select * into v_order
    from public.orders
    where id = p_order_id
    for update;
  if not found then
    raise exception 'Order not found';
  end if;

  if jsonb_typeof(v_order.status_history) = 'array' then
    select exists (
      select 1
        from jsonb_array_elements(v_order.status_history) as entry
        where entry->>'status' = 'Payment Verified'
          and entry->>'updatedBy' = 'PayU'
    ) into v_paid;
  else
    v_paid := false;
  end if;
  if v_paid then
    return jsonb_build_object('order', to_jsonb(v_order), 'updated', false);
  end if;
  if v_order.status <> 'Payment Verification Pending' or
     v_order.reference_id is distinct from p_reference_id then
    return jsonb_build_object('order', to_jsonb(v_order), 'updated', false);
  end if;

  if not v_order.stock_reserved then
    perform public.reserve_order_stock(v_order.items);
  end if;

  v_history := case
    when jsonb_typeof(v_order.status_history) = 'array' then v_order.status_history
    else '[]'::jsonb
  end;
  v_history := v_history || jsonb_build_array(jsonb_build_object(
    'status', 'Payment Verified',
    'timestamp', now(),
    'updatedBy', 'PayU',
    'details', 'PayU ID: ' || coalesce(nullif(p_mihpayid, ''), 'N/A')
  ));

  update public.orders
    set status = 'Payment Verified',
        status_history = v_history,
        stock_reserved = true,
        updated_at = now()
    where id = p_order_id
    returning * into v_order;
  return jsonb_build_object('order', to_jsonb(v_order), 'updated', true);
end;
$$;

create or replace function public.initiate_order_payment(
  p_order_id uuid,
  p_user_id uuid,
  p_reference_id text,
  p_status_history jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_order public.orders;
begin
  select * into v_order
    from public.orders
    where id = p_order_id
    for update;
  if not found or v_order.user_id is distinct from p_user_id or
     v_order.payment_method <> 'online' or
     v_order.status not in ('Payment Verification Pending', 'Payment Failed') then
    raise exception 'Order cannot start a payment';
  end if;
  if v_order.status = 'Payment Verification Pending' and v_order.reference_id is not null then
    raise exception 'Payment already in progress';
  end if;

  if not v_order.stock_reserved then
    perform public.reserve_order_stock(v_order.items);
  end if;

  update public.orders
    set reference_id = p_reference_id,
        status = 'Payment Verification Pending',
        status_history = case
          when jsonb_typeof(p_status_history) = 'array' then p_status_history
          else status_history
        end,
        stock_reserved = true,
        updated_at = now()
    where id = p_order_id
    returning * into v_order;
  return to_jsonb(v_order);
end;
$$;

create or replace function public.release_order_stock(
  p_order_id uuid,
  p_target_status text,
  p_status_history jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_order public.orders;
  v_item jsonb;
  v_product_id uuid;
  v_qty integer;
begin
  if p_target_status not in ('Cancelled', 'Payment Failed') then
    raise exception 'Invalid release status';
  end if;

  select * into v_order
    from public.orders
    where id = p_order_id
    for update;
  if not found then
    raise exception 'Order not found';
  end if;
  if v_order.status = p_target_status then
    return to_jsonb(v_order);
  end if;
  if (p_target_status = 'Payment Failed' and
      (v_order.payment_method <> 'online' or v_order.status <> 'Payment Verification Pending')) or
     (p_target_status = 'Cancelled' and
      (v_order.status not in ('Pending', 'Payment Verification Pending', 'Payment Failed', 'Confirmed') or
       (v_order.payment_method = 'online' and
        v_order.status = 'Payment Verification Pending' and
        v_order.reference_id is not null))) then
    return to_jsonb(v_order);
  end if;

  if v_order.stock_reserved then
    for v_item in select * from jsonb_array_elements(v_order.items)
    loop
      v_product_id := nullif(v_item->>'product_id', '')::uuid;
      v_qty := (v_item->>'qty')::integer;
      if v_product_id is null or v_qty is null or v_qty < 1 then
        raise exception 'Invalid reserved order item';
      end if;
      update public.products
        set stock = stock + v_qty,
            updated_at = now()
        where id = v_product_id;
    end loop;
  end if;

  update public.orders
    set status = p_target_status,
        status_history = case
          when jsonb_typeof(p_status_history) = 'array' then p_status_history
          else status_history
        end,
        stock_reserved = false,
        updated_at = now()
    where id = p_order_id
    returning * into v_order;
  return to_jsonb(v_order);
end;
$$;

revoke all on function public.reserve_order_stock(jsonb) from public, anon, authenticated;
revoke all on function public.create_order_with_stock(jsonb, jsonb, text, uuid) from public, anon, authenticated;
revoke all on function public.confirm_order_payment(uuid, text, text) from public, anon, authenticated;
revoke all on function public.initiate_order_payment(uuid, uuid, text, jsonb) from public, anon, authenticated;
revoke all on function public.release_order_stock(uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.create_order_with_stock(jsonb, jsonb, text, uuid) to service_role;
grant execute on function public.confirm_order_payment(uuid, text, text) to service_role;
grant execute on function public.initiate_order_payment(uuid, uuid, text, jsonb) to service_role;
grant execute on function public.release_order_stock(uuid, text, jsonb) to service_role;
