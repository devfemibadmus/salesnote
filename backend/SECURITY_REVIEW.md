# Backend Security Review

Date: 2026-03-07
Scope: `backend/src`
Method: static code review only

This is a tracking document for backend security work. Findings are ordered by severity, then by fix value.

## Findings

| ID | Severity | Status | Title |
| --- | --- | --- | --- |
| SEC-001 | High | Implemented | Weak password policy |
| SEC-002 | High | Implemented | Image decode path is vulnerable to memory/CPU exhaustion |
| SEC-003 | Medium | Implemented | Signup flow leaks account existence |
| SEC-004 | Medium | Implemented | Client IP and geo headers are trusted without a trusted-proxy boundary |
| SEC-005 | Medium | Implemented | Uploaded files are exposed publicly under `/uploads` |
| SEC-006 | Low | Open | Production logging defaults are too verbose |
| SEC-007 | Medium | Implemented | Brute-force and spam protection is only partial on auth flows |
| SEC-008 | Medium | Implemented | User-controlled values are inserted into HTML email templates without escaping |

## Detailed Findings

### SEC-001: Weak password policy

- Severity: High
- Status: Implemented
- Locations:
  - `backend/src/api/handlers/auth.rs:450`
  - `backend/src/api/handlers/auth.rs:456`
  - `backend/src/api/handlers/auth.rs:606`
  - `backend/src/api/handlers/auth.rs:609`
- Current behavior:
  - Passwords are accepted at 5 to 20 characters.
  - This is too weak on the minimum side and too restrictive on the maximum side.
  - Restricting to 20 also blocks long passphrases, which are usually the safest option for normal users.
- Risk:
  - Easier brute-force and credential-stuffing success.
  - Users are pushed toward short passwords instead of passphrases.
- Recommended fix:
  - Move to a stronger policy such as minimum 8 or 10 characters and maximum at least 64 or 128.
  - Prefer allowing long passphrases over forcing special-character rules.
  - Apply the same validation in register, reset password, and shop password update paths.
- Implemented:
  - minimum password length changed to 8
  - maximum password length changed to 128
  - applied in register, reset password, and shop profile password update

### SEC-002: Image decode path is vulnerable to memory/CPU exhaustion

- Severity: High
- Status: Implemented
- Locations:
  - `backend/src/api/handlers/shops.rs:152`
  - `backend/src/api/handlers/shops.rs:162`
  - `backend/src/api/handlers/signatures.rs:77`
  - `backend/src/api/handlers/signatures.rs:176`
- Current behavior:
  - Uploaded images are size-limited by bytes, but then fully decoded in memory with `image::load_from_memory(...)`.
  - A small compressed image can still expand into a very large bitmap during decode.
  - Signature processing also converts the decoded image to RGBA, which increases memory pressure further.
- Risk:
  - Memory exhaustion.
  - CPU exhaustion during image decoding and processing.
  - Easier denial-of-service through crafted images.
- Recommended fix:
  - Parse image metadata first and reject extreme dimensions before full decode.
  - Add explicit max pixel count, for example width * height cap.
  - Consider decode timeouts or worker isolation for expensive image processing.
  - Log rejected images with safe metadata only.
- Implemented:
  - source image metadata is now inspected before full decode
  - source dimension cap added
  - source pixel-count cap added
  - applied to both shop logo and signature upload paths

### SEC-003: Signup flow leaks account existence

- Severity: Medium
- Status: Implemented
- Locations:
  - `backend/src/api/handlers/auth.rs:55`
  - `backend/src/api/handlers/auth.rs:170`
- Current behavior:
  - Signup returns `phone or email already exists`.
  - This makes user enumeration possible for phone numbers and email addresses.
- Risk:
  - Attackers can confirm whether a target account exists.
  - This increases phishing and credential-stuffing precision.
- Recommended fix:
  - Return a generic response for signup initiation and signup verification failures.
  - Keep the exact duplicate reason only in internal logs.
  - If product wants nicer UX, only reveal duplicate state after stronger proof of ownership.
- Implemented:
  - signup initiation now returns a generic success response even when the account already exists
  - duplicate-account races during signup verification now return a generic invalid-code response
  - exact duplicate reasons are kept only in server logs

### SEC-004: Client IP and geo headers are trusted without a trusted-proxy boundary

- Severity: Medium
- Status: Implemented
- Locations:
  - `backend/src/api/handlers/auth.rs:538`
  - `backend/src/api/handlers/auth.rs:542`
  - `backend/src/api/handlers/auth.rs:547`
  - `backend/src/api/handlers/auth.rs:565`
  - `backend/src/api/handlers/auth.rs:577`
  - `backend/src/api/handlers/auth.rs:585`
  - `backend/src/api/middlewares/rate_limit.rs:83`
- Current behavior:
  - The API reads `X-Forwarded-For`, `X-Real-IP`, `X-Geo-City`, `X-Geo-Region`, and `CF-IPCountry` directly.
  - These values are then used for device session metadata and request attribution.
  - The rate-limit path also depends on resolved remote address behavior.
- Risk:
  - If the API is ever reachable directly or the proxy chain is misconfigured, request origin and location data can be spoofed.
  - Device logs and security telemetry become unreliable.
  - Rate-limit behavior may be bypassed or distorted depending on proxy setup.
- Recommended fix:
  - Accept forwarded headers only from a trusted reverse proxy boundary.
  - Prefer a single sanitized upstream header set by nginx.
  - Document and enforce direct-port blocking so clients cannot bypass the proxy.
- Implemented:
  - added a configured trusted-proxy boundary via `SALESNOTE__TRUSTED_PROXY_RANGES`
  - `X-Forwarded-For`, `X-Real-IP`, and geo headers are now used only when the direct peer IP is trusted
  - auth session metadata and rate-limit attribution now use the same shared trust logic

### SEC-005: Uploaded files are exposed publicly under `/uploads`

- Severity: Medium
- Status: Implemented
- Locations:
  - `backend/src/bin/api.rs:64`
  - `backend/src/api/handlers/shops.rs:305`
  - `backend/src/api/handlers/signatures.rs:171`
- Current behavior:
  - The API serves `uploads/` publicly.
  - Shop logos and signature images are stored under that public path.
- Risk:
  - Anyone who knows or guesses a file URL can fetch it without auth.
  - Signatures may be sensitive enough that public direct access is not acceptable.
- Recommended fix:
  - Decide explicitly whether logos and signatures are meant to be public.
  - If not public, move them behind authenticated handlers or signed URLs.
  - If public is intentional, document that decision and avoid storing anything sensitive there.
- Implemented:
  - new GCS-backed uploads are now stored as internal `gcs://bucket/object` references instead of public URLs
  - API responses resolve those references into short-lived signed read URLs
  - bucket can remain private while mobile/web clients continue receiving usable `logo_url` and `image_url` fields

### SEC-006: Production logging defaults are too verbose

- Severity: Low
- Status: Open
- Locations:
  - `backend/src/config.rs:86`
  - `backend/src/config.rs:303`
- Current behavior:
  - Default tracing falls back to `trace` if no env filter is set.
  - SQL error logging is enabled by default.
- Risk:
  - Overly broad logs in production.
  - Increased chance of sensitive operational data appearing in logs.
  - Harder incident review because high-volume logs reduce signal quality.
- Recommended fix:
  - Default production log level to `info` or `warn`.
  - Make trace-level logging opt-in only.
  - Keep SQL logging minimal and avoid broad debug/trace defaults.

### SEC-007: Brute-force and spam protection is only partial on auth flows

- Severity: Medium
- Status: Implemented
- Locations:
  - `backend/src/api/handlers/auth.rs:41`
  - `backend/src/api/handlers/auth.rs:58`
  - `backend/src/api/handlers/auth.rs:237`
  - `backend/src/api/handlers/auth.rs:343`
  - `backend/src/api/middlewares/rate_limit.rs:120`
  - `backend/src/bin/api.rs:65`
- Current behavior:
  - There is some protection already:
    - login lockout after repeated failures
    - reset/signup code incorrect-attempt limit
    - forgot-password and signup resend window limits
    - global rate limiter middleware
  - But the protections are still fairly basic:
    - login lockout is account-based, not risk-based
    - signup and forgot-password email sending can still be abused from distributed sources
    - there is no CAPTCHA, proof-of-work, or stronger anti-automation gate on email-triggering endpoints
    - rate limiting is generic, not route-sensitive
- Risk:
  - Distributed brute-force attempts can still pressure login and reset flows.
  - Email-triggering endpoints can still be used for nuisance or spam against known accounts.
  - Abuse handling is present, but not strong enough for a public internet-facing auth surface.
- Recommended fix:
  - Add stricter per-route rate limits for `/auth/login`, `/auth/register`, `/auth/forgot-password`, `/auth/verify-code`, and `/auth/register/verify`.
  - Add a lightweight challenge on spam-prone endpoints, for example CAPTCHA on repeated attempts.
  - Consider separate per-IP and per-account throttles.
  - Log and alert on repeated abuse patterns.
- Implemented:
  - added stricter route-specific throttles for the public auth endpoints on top of the global limiter
  - rate-limit keys are now scoped by route plus requester identity
  - `Retry-After: 60` is returned on rate-limited responses
  - no CAPTCHA was added

### SEC-008: User-controlled values are inserted into HTML email templates without escaping

- Severity: Medium
- Status: Implemented
- Locations:
  - `backend/src/api/email/mod.rs:165`
  - `backend/src/api/email/mod.rs:171`
  - `backend/src/worker/email/message.rs:19`
  - `backend/src/worker/email/message.rs:25`
- Current behavior:
  - `shop_name` and other dynamic values are inserted into HTML email templates using raw `.replace(...)` and `format!(...)`.
  - Only the numeric code-box characters are HTML-escaped.
  - Shop-controlled values are not escaped before being placed into HTML.
- Risk:
  - Stored HTML injection in outbound emails.
  - Layout breakage or malicious markup in email clients if a user registers with crafted values.
  - This is not the same as SQL injection, but it is still input injection into a rendered HTML surface.
- Recommended fix:
  - HTML-escape all user-controlled values before template substitution.
  - Add a small shared escaping helper for every dynamic template field, not just code digits.
  - Review web surfaces too if they render stored names/addresses as HTML anywhere.
- Implemented:
  - auth email templates now escape user-controlled string fields before substitution
  - worker welcome email now escapes dynamic string fields before substitution
  - code digits continue to be escaped before rendering into the code-box markup

## Requested Focus Areas

### Brute force

- Status: Partial protection exists, not closed.
- Present controls:
  - login lockout
  - code attempt caps
  - forgot/signup request windows
  - global rate limit
- Remaining concern:
  - public auth endpoints still need stronger abuse-specific throttling.

### Spam

- Status: Partial protection exists, not closed.
- Present controls:
  - resend windows on signup and forgot-password
  - generic rate limiting
- Remaining concern:
  - no stronger anti-bot or anti-abuse step on email-triggering endpoints.

### Injections in inputs

- SQL injection:
  - I did not find a primary SQL injection path in this pass.
  - Most database access is using bound parameters through `sqlx::query(...).bind(...)`.
- Still-open injection class:
  - HTML/template injection in emails is real and should be fixed.
  - Any web client rendering stored values unsafely could turn this into XSS.

## Suggested Fix Order

1. SEC-001
2. SEC-002
3. SEC-007
4. SEC-008
5. SEC-004
6. SEC-003
7. SEC-005
8. SEC-006

## Notes

- This review is based on code inspection only.
- No dynamic testing, fuzzing, dependency audit, or infrastructure validation was performed in this pass.
- Reverse proxy behavior matters for SEC-004 and SEC-005. Confirm nginx and firewall posture before closing those items.
