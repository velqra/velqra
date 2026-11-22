const normalizeInternationalPhone = value => {
  const phone = String(value || '').trim();
  return /^\+[1-9]\d{6,14}$/.test(phone) ? phone : '';
};

const normalizeIndianPhone = value => {
  let digits = String(value || '').replace(/\D/g, '');
  if (/^91[6-9]\d{9}$/.test(digits)) digits = digits.slice(2);
  return /^[6-9]\d{9}$/.test(digits) ? digits : '';
};

module.exports = { normalizeInternationalPhone, normalizeIndianPhone };
