import http from 'k6/http';
import { check, fail } from 'k6';

import { credentials, defaults, runtime } from './config.js';

const baseUrl = runtime.baseUrl;

function parseJson(response, context) {
  let body;
  try {
    body = response.json();
  } catch (error) {
    fail(`${context} returned non-JSON response: ${response.body}`);
  }

  if (!body || typeof body !== 'object') {
    fail(`${context} returned invalid JSON body.`);
  }

  return body;
}

export function jsonParams(token) {
  const headers = {
    'Content-Type': 'application/json',
  };

  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  return { headers };
}

export function expectStatus(response, statuses, context) {
  const allowed = Array.isArray(statuses) ? statuses : [statuses];
  check(response, {
    [`${context} status is expected`]: (res) => allowed.includes(res.status),
  });

  if (!allowed.includes(response.status)) {
    const body = parseJson(response, context);
    const message = body && body.error ? body.error.message : response.body;
    fail(`${context} failed with ${response.status}: ${message}`);
  }
}

export function expectSuccess(response, context, statuses = [200]) {
  expectStatus(response, statuses, context);
  const body = parseJson(response, context);
  check(body, {
    [`${context} success envelope`]: (payload) => payload.success === true,
  });
  if (body.success !== true) {
    const message = body && body.error ? body.error.message : 'unknown error';
    fail(`${context} returned success=false: ${message}`);
  }
  return body.data;
}

export function health() {
  const response = http.get(`${baseUrl}/health`);
  return expectSuccess(response, 'health');
}

export function login(loginId = credentials.loginId, password = credentials.password) {
  const response = http.post(
    `${baseUrl}/auth/login`,
    JSON.stringify({
      phone_or_email: loginId,
      password,
      device_name: 'k6-local',
      device_platform: 'k6',
      device_os: 'local',
    }),
    jsonParams()
  );

  const data = expectSuccess(response, 'login');
  if (!data || !data.access_token) {
    fail('login response missing access_token');
  }
  return data;
}

export function listSignatures(token) {
  const response = http.get(`${baseUrl}/signatures`, jsonParams(token));
  return expectSuccess(response, 'list signatures');
}

export function createSignature(
  token,
  name = defaults.signatureName,
  imageUrl = defaults.signatureImageUrl
) {
  const imageResponse = http.get(imageUrl, { responseType: 'binary' });
  expectStatus(imageResponse, 200, 'download signature image');

  const file = http.file(imageResponse.body, 'seed-signature.jpg', 'image/jpeg');
  const response = http.post(
    `${baseUrl}/signatures`,
    { name, image: file },
    {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    }
  );

  return expectSuccess(response, 'create signature', [201]);
}

export function ensureSignature(token) {
  const signatures = listSignatures(token);
  if (Array.isArray(signatures) && signatures.length > 0) {
    return signatures[0];
  }

  return createSignature(token);
}

export function getHome(token) {
  const response = http.get(`${baseUrl}/home`, jsonParams(token));
  return expectSuccess(response, 'home');
}

export function getShop(token) {
  const response = http.get(`${baseUrl}/shop`, jsonParams(token));
  return expectSuccess(response, 'shop');
}

export function getSettings(token) {
  const response = http.get(`${baseUrl}/settings`, jsonParams(token));
  return expectSuccess(response, 'settings');
}

export function listSales(token, includeItems = false) {
  const response = http.get(
    `${baseUrl}/sales?page=1&per_page=20&include_items=${includeItems ? 'true' : 'false'}`,
    jsonParams(token)
  );
  return expectSuccess(response, 'list sales');
}

export function getAnalyticsSummary(token) {
  const response = http.get(`${baseUrl}/analytics/summary`, jsonParams(token));
  return expectSuccess(response, 'analytics summary');
}

export function createSale(token, payload) {
  const response = http.post(
    `${baseUrl}/sales`,
    JSON.stringify(payload),
    jsonParams(token)
  );
  return expectSuccess(response, 'create sale', [201]);
}

export function buildSalePayload(signatureId, suffix) {
  const safeSuffix = String(suffix);
  return {
    signature_id: signatureId,
    customer_name: `Perf Customer ${safeSuffix}`,
    customer_contact: `+1555${safeSuffix.padStart(8, '0').slice(-8)}`,
    discount_amount: 0,
    vat_amount: 0,
    service_fee_amount: 0,
    delivery_fee_amount: 0,
    rounding_amount: 0,
    other_amount: 0,
    other_label: '',
    items: [
      {
        product_name: `ItemA${safeSuffix}`.slice(0, 20),
        quantity: 1,
        unit_price: 1500,
      },
      {
        product_name: `ItemB${safeSuffix}`.slice(0, 20),
        quantity: 2,
        unit_price: 800,
      },
    ],
  };
}
