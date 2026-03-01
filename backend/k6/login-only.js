import { group, sleep } from 'k6';

import { login } from './lib/api.js';
import { buildOptions, buildScenario, defaults, requireCredentials } from './lib/config.js';

export const options = buildOptions({
  scenarios: buildScenario('login_users'),
  thresholds: {
    http_req_failed: ['rate<0.02'],
    http_req_duration: ['p(95)<1000'],
    checks: ['rate>0.98'],
  },
});

export default function () {
  requireCredentials();

  group('login-only', () => {
    login();
  });

  sleep(defaults.thinkTimeSecs);
}
