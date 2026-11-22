const axios = require('axios');

const OTPFLOW_BASE_URL = 'https://otpflow.in';

const sendOtpFlow = async ({
  apiKey,
  number,
  purpose,
  ttl = 10,
  otpLength = 6,
  httpClient = axios
}) => {
  if (!apiKey) return { sent: false, reason: 'no_api_key' };

  try {
    const { data } = await httpClient.post(`${OTPFLOW_BASE_URL}/send-otp`, {
      number,
      purpose,
      ttl,
      otp_length: otpLength
    }, {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      timeout: 15000
    });

    const expiresAt = Date.parse(data?.expires_at);
    if (data?.success !== true || typeof data.otp_id !== 'string' ||
        !data.otp_id || !Number.isFinite(expiresAt) || expiresAt <= Date.now()) {
      return { sent: false, reason: 'invalid_response' };
    }

    return { sent: true, otpId: data.otp_id, expiresAt: data.expires_at };
  } catch (error) {
    console.error('OTPFlow send failed:', {
      status: error.response?.status,
      code: error.code
    });
    return {
      sent: false,
      reason: error.response?.status === 402 ? 'insufficient_balance' : 'provider_error'
    };
  }
};

const verifyOtpFlow = async ({ apiKey, otpId, otp, httpClient = axios }) => {
  if (!apiKey || !otpId) return { verified: false, unavailable: true };

  try {
    const { data } = await httpClient.post(`${OTPFLOW_BASE_URL}/verify-otp`, {
      otp_id: otpId,
      otp: String(otp)
    }, {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      timeout: 15000
    });

    return { verified: data?.success === true && data?.verified === true };
  } catch (error) {
    const status = error.response?.status;
    if ([400, 404, 409, 410].includes(status)) return { verified: false };
    if (status === 429) return { verified: false, rateLimited: true };

    console.error('OTPFlow verification failed:', { status, code: error.code });
    return { verified: false, unavailable: true };
  }
};

module.exports = { sendOtpFlow, verifyOtpFlow };
