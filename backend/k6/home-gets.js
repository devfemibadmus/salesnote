import { group, sleep } from 'k6';

import { getAnalyticsSummary, getHome, getSettings, getShop, login } from './lib/api.js';
import { buildOptions, buildScenario, defaults, requireCredentials } from './lib/config.js';

export const options = buildOptions({
  scenarios: buildScenario('home_get_users'),
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
  group('home-gets', () => {
    getHome(data.token);
    getAnalyticsSummary(data.token);
    getShop(data.token);
    getSettings(data.token);
  });

  sleep(defaults.thinkTimeSecs);
}
