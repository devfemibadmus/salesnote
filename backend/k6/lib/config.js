import localConfig from '../local.config.js';

const DEFAULT_BASE_URL = 'http://127.0.0.1:8080';
const LOCAL = localConfig || {};

function envInt(name, fallback) {
  const raw = __ENV[name];
  if (!raw) {
    return fallback;
  }

  const parsed = parseInt(raw, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function envBool(name, fallback) {
  const raw = (__ENV[name] || '').trim().toLowerCase();
  if (!raw) {
    return fallback;
  }
  return raw === '1' || raw === 'true' || raw === 'yes' || raw === 'on';
}

export const baseUrl = (__ENV.BASE_URL || DEFAULT_BASE_URL).replace(/\/+$/, '');

export const credentials = {
  loginId: __ENV.LOGIN_ID || LOCAL.loginId || '',
  password: __ENV.LOGIN_PASSWORD || LOCAL.password || '',
};

export const defaults = {
  vus: envInt('VUS', LOCAL.vus || 10),
  duration: __ENV.DURATION || LOCAL.duration || '30s',
  executionMode: (__ENV.EXECUTION_MODE || LOCAL.executionMode || 'duration').trim().toLowerCase(),
  perVuIterations: envInt('PER_VU_ITERATIONS', LOCAL.perVuIterations || 10),
  thinkTimeSecs: envInt('THINK_TIME_SECS', LOCAL.thinkTimeSecs || 1),
  includeItems: envBool('INCLUDE_ITEMS', LOCAL.includeItems ?? false),
  signatureName: __ENV.SIGNATURE_NAME || LOCAL.signatureName || 'Amanda',
  signatureImageUrl:
    __ENV.SIGNATURE_IMAGE_URL ||
    LOCAL.signatureImageUrl ||
    'https://aisignator.com/wp-content/uploads/2025/05/Amanda-signature.jpg',
};

export const runtime = {
  baseUrl: (__ENV.BASE_URL || LOCAL.baseUrl || DEFAULT_BASE_URL).replace(/\/+$/, ''),
};

export function buildOptions(extra = {}) {
  const base = {
    thresholds: {
      http_req_failed: ['rate<0.05'],
      http_req_duration: ['p(95)<1200'],
      checks: ['rate>0.95'],
    },
  };

  if (!extra.scenarios) {
    base.vus = defaults.vus;
    base.duration = defaults.duration;
  }

  return {
    ...base,
    ...extra,
  };
}

export function buildScenario(name) {
  if (defaults.executionMode === 'iterations') {
    return {
      [name]: {
        executor: 'per-vu-iterations',
        vus: defaults.vus,
        iterations: defaults.perVuIterations,
        maxDuration: LOCAL.maxDuration || __ENV.MAX_DURATION || '10m',
      },
    };
  }

  return {
    [name]: {
      executor: 'constant-vus',
      vus: defaults.vus,
      duration: defaults.duration,
    },
  };
}

export function requireCredentials() {
  if (!credentials.loginId || !credentials.password) {
    throw new Error(
      'Set loginId/password in backend/k6/local.config.js or use LOGIN_ID/LOGIN_PASSWORD env vars.'
    );
  }
}
