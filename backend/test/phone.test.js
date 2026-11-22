const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizeInternationalPhone, normalizeIndianPhone } = require('../utils/phone');

test('normalizes only valid international E.164 values', () => {
  assert.equal(normalizeInternationalPhone('+14155552671'), '+14155552671');
  assert.equal(normalizeInternationalPhone('14155552671'), '');
  assert.equal(normalizeInternationalPhone('+0123456789'), '');
  assert.equal(normalizeInternationalPhone('+12345'), '');
});

test('accepts Indian local and +91 mobile numbers for COD verification', () => {
  assert.equal(normalizeIndianPhone('9876543210'), '9876543210');
  assert.equal(normalizeIndianPhone('+919876543210'), '9876543210');
  assert.equal(normalizeIndianPhone('1234567890'), '');
});
