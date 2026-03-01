import { group, sleep } from 'k6';

import { listSales, login } from './lib/api.js';
import { buildOptions, buildScenario, defaults, requireCredentials } from './lib/config.js';

export const options = buildOptions({
  scenarios: buildScenario('sales_list_users'),
  thresholds: {
    http_req_failed: ['rate<0.02'],
    http_req_duration: ['p(95)<1000'],
    checks: ['rate>0.98'],
  },
});

export function setup() {
  requireCredentials();
  const auth = login();
  return { token: auth.access_token };
}

export default function (data) {
  group('sales-list', () => {
    listSales(data.token, false);
  });

  sleep(defaults.thinkTimeSecs);
}
