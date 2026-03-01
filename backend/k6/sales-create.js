import exec from 'k6/execution';
import { group, sleep } from 'k6';

import { buildSalePayload, createSale, ensureSignature, login } from './lib/api.js';
import { buildOptions, buildScenario, defaults, requireCredentials } from './lib/config.js';

function resolveSignatureId(token) {
  const signature = ensureSignature(token);
  if (!signature || !signature.id) {
    throw new Error('Unable to load or create a signature for sales-create.');
  }

  return signature.id;
}

export const options = buildOptions({
  scenarios: buildScenario('sales_create_users'),
  thresholds: {
    http_req_failed: ['rate<0.02'],
    http_req_duration: ['p(95)<1200'],
    checks: ['rate>0.98'],
  },
});

export function setup() {
  requireCredentials();
  const auth = login();
  const signatureId = resolveSignatureId(auth.access_token);
  return { token: auth.access_token, signatureId };
}

export default function (data) {
  const suffix = `${exec.vu.idInTest}-${exec.scenario.iterationInTest}`;

  group('sales-create', () => {
    createSale(data.token, buildSalePayload(data.signatureId, suffix));
  });

  sleep(defaults.thinkTimeSecs);
}
