# Mobile Improvements

Date: 2026-03-07
Scope: `mobile/lib`
Method: static code review only

This is a tracking document for mobile improvements. Items are ordered by fix priority.

## Tracker

| ID | Severity | Status | Title |
| --- | --- | --- | --- |
| MOB-001 | High | Implemented | Signed media cache keys are unstable |
| MOB-002 | Medium | Implemented | API client crashes on non-JSON error responses |
| MOB-003 | Medium | Implemented | Auth token is stored in SharedPreferences |
| MOB-004 | Low | Implemented | Suggestion query URL is built by raw string interpolation |

## Details

### MOB-001: Signed media cache keys are unstable

- Severity: High
- Status: Implemented
- Locations:
  - `mobile/lib/services/media.dart`
  - `mobile/lib/services/cache/local.dart`
- Current behavior:
  - Media is cached by full URL string.
  - Signed GCS URLs change over time even when they point to the same object.
  - That makes cache hits unreliable and causes duplicate cached entries for the same image.
- Risk:
  - Cache misses after every signed URL refresh.
  - Unbounded cache growth for the same logical image.
  - More network fetches than necessary.
- Recommended fix:
  - Strip signed query parameters before building cache keys, or
  - cache by a stable object identifier returned by the API.
- Implemented:
  - media cache keys now ignore volatile query strings and fragments
  - signed GCS URLs are no longer mutated with local cache-bust parameters
  - shop logo updates now keep the backend URL unchanged and rely on cache overwrite instead of URL rewriting

### MOB-002: API client crashes on non-JSON error responses

- Severity: Medium
- Status: Implemented
- Locations:
  - `mobile/lib/services/api_client.dart`
- Current behavior:
  - The API client always calls `jsonDecode(response.body)`.
  - If the backend, nginx, or a proxy returns HTML, plain text, or an empty body, the app throws a `FormatException`.
- Risk:
  - Broken error handling for real production failures like `502`, `503`, `504`, or upstream error pages.
  - User gets unstable or misleading failures instead of a controlled app error message.
- Recommended fix:
  - Guard JSON decoding.
  - Fall back to raw status/body handling when the response is not JSON.
- Implemented:
  - API response parsing now tries JSON decoding safely
  - non-JSON, HTML, text, or empty responses now fall back into normal status/body error handling instead of throwing `FormatException`

### MOB-003: Auth token is stored in SharedPreferences

- Severity: Medium
- Status: Implemented
- Locations:
  - `mobile/lib/services/token_store.dart`
- Current behavior:
  - Bearer auth token is stored in `SharedPreferences`.
- Risk:
  - Weaker on-device protection than secure platform storage.
  - Easier extraction on compromised devices or during local data inspection.
- Recommended fix:
  - Move token storage to Keychain/Keystore via secure storage.
- Implemented:
  - auth token storage now uses `flutter_secure_storage`
  - existing SharedPreferences tokens are migrated on first read so current users keep their session
  - iOS runner entitlements now include Keychain Sharing for secure storage access

### MOB-004: Suggestion query URL is built by raw string interpolation

- Severity: Low
- Status: Implemented
- Locations:
  - `mobile/lib/services/api_client.dart`
- Current behavior:
  - Suggestion URL is built with raw string interpolation for `key` and `query`.
- Risk:
  - Special characters in the query can break the request.
  - Request parameters can be malformed for `&`, `?`, `#`, `+`, or non-ASCII input.
- Recommended fix:
  - Build the URL with `Uri.replace(queryParameters: ...)`.
- Implemented:
  - suggestion requests now use `Uri.replace(queryParameters: ...)`
  - special characters in search input are now encoded safely instead of corrupting the request URL

## Fix Order

1. MOB-001
2. MOB-002
3. MOB-003
4. MOB-004

## Notes

- This review is based on code inspection only.
- No runtime profiling or integration testing was performed in this pass.
