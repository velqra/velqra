const test = require('node:test');
const assert = require('node:assert/strict');
const { sendOtpFlow, verifyOtpFlow } = require('../utils/otpflow');

test('sends an OTP through OTPFlow and returns its verification id', async () => {
  let request;
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();
  const result = await sendOtpFlow({
    apiKey: 'test-key',
    number: '9876543210',
    purpose: 'registration',
    httpClient: {
      async post(url, body, options) {
        request = { url, body, options };
        return {
          data: {
            success: true,
            otp_id: 'otp_test123',
            expires_at: expiresAt
          }
        };
      }
    }
  });

  assert.equal(request.url, 'https://otpflow.in/send-otp');
  assert.deepEqual(request.body, {
    number: '9876543210',
    purpose: 'registration',
    ttl: 10,
    otp_length: 6
  });
  assert.equal(request.options.headers.Authorization, 'Bearer test-key');
  assert.deepEqual(result, {
    sent: true,
    otpId: 'otp_test123',
    expiresAt
  });
});

test('rejects invalid OTPFlow send responses and missing credentials', async () => {
  const missingKey = await sendOtpFlow({ number: '9876543210', purpose: 'login' });
  const invalidResponse = await sendOtpFlow({
    apiKey: 'test-key',
    number: '9876543210',
    purpose: 'login',
    httpClient: {
      async post() {
        return {
          data: {
            success: true,
            otp_id: 'otp_expired',
            expires_at: '2020-01-01T00:00:00.000Z'
          }
        };
      }
    }
  });

  assert.deepEqual(missingKey, { sent: false, reason: 'no_api_key' });
  assert.deepEqual(invalidResponse, { sent: false, reason: 'invalid_response' });
});

test('verifies OTPFlow codes and treats provider rejection as an invalid code', async () => {
  const verified = await verifyOtpFlow({
    apiKey: 'test-key',
    otpId: 'otp_test123',
    otp: '123456',
    httpClient: {
      async post(url, body, options) {
        assert.equal(url, 'https://otpflow.in/verify-otp');
        assert.deepEqual(body, { otp_id: 'otp_test123', otp: '123456' });
        assert.equal(options.headers.Authorization, 'Bearer test-key');
        return { data: { success: true, verified: true } };
      }
    }
  });
  const invalid = await verifyOtpFlow({
    apiKey: 'test-key',
    otpId: 'otp_test123',
    otp: '000000',
    httpClient: {
      async post() {
        const error = new Error('Invalid OTP');
        error.response = { status: 400 };
        throw error;
      }
    }
  });

  assert.deepEqual(verified, { verified: true });
  assert.deepEqual(invalid, { verified: false });
});
