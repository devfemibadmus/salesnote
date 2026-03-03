import { group, sleep } from 'k6';

import { listSales, login } from './lib/api.js';
import { buildOptions, buildScenario, defaults, requireCredentials } from './lib/config.js';

export const options = buildOptions({
  scenarios: buildScenario('item_list_users'),
  thresholds: {
    http_req_failed: ['rate<0.02'],
    http_req_duration: ['p(95)<3000'],
    checks: ['rate>0.98'],
  },
});

export function setup() {
  requireCredentials();
  const auth = login();
  return { token: auth.access_token };
}

export default function (data) {
  group('item-list', () => {
    // Backend exposes items through sales list with include_items=true.
    listSales(data.token, true);
  });

  sleep(defaults.thinkTimeSecs);
}
