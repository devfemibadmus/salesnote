# Salesnote Backend

Minimal Rust REST API scaffold for the Salesnote.ng MVP.

## Running (once Rust is installed)

```bash
cd backend
cargo run --bin api
```

## Worker (Email + Notifications + Geo IP)

```bash
cd backend
cargo run --bin worker
```

## Seed (optional)

```bash
cd backend
set SALESNOTE__SEED_SHOP_NAME=Demo Shop
set SALESNOTE__SEED_SHOP_PHONE=08012345678
set SALESNOTE__SEED_SHOP_EMAIL=demo@example.com
set SALESNOTE__SEED_SHOP_PASSWORD=demo123
set SALESNOTE__SEED_SHOP_ADDRESS=12 Lagos Island Market
cargo run --bin seed
```

## Auth + Shop
- `POST /auth/register` (phone/email/password + shop profile with address + timezone)
- `POST /auth/login` (phone or email + password)
- `POST /auth/refresh` (refresh token -> new access token)
- `POST /auth/forgot-password` (email; rate-limited to 2 requests per 2 hours)
- `GET /shop` (current shop)
- `PATCH /shop` (update current shop; multipart with optional `logo` image)
- `POST /shop/subscribe` (JSON `{ "fcm_token": "..." }`)
- `GET /devices` (list logged-in devices)
- `DELETE /devices/:id` (logout device)

## Suggestions (key/value history)
- `POST /suggestions` (store or increment usage)
- `GET /suggestions?key=product&q=ri&limit=10`

## Signatures
- `POST /signatures` (multipart: `name` + `image`, max 3 per shop)
- `GET /signatures`
- `DELETE /signatures/:id`

## Sales
- `GET /sales`
- `POST /sales`
  - Optional `suggestions` array of `{ key, value }` to store history hints
- `PATCH /sales/:id` (allowed only within 24 hours of creation)
- `DELETE /sales/:id` (allowed only within 24 hours of creation)

## Analytics
- `GET /analytics/summary`

## Receipts
- `POST /receipts` (stores receipt record)
- `GET /receipts` (list receipts)
- `GET /receipts/:id` (receipt detail: shop + sale + items + signature)

## Config
App loads settings only from `.env` (required). If `.env` is missing, the app exits.

Example:

```bash
SALESNOTE__BIND=0.0.0.0:8080
SALESNOTE__DATABASE_URL=postgres://salesnote:password123@127.0.0.1:5432/salesnote
SALESNOTE__JWT_SECRET=change-me
SALESNOTE__REFRESH_TOKEN_DAYS=30
SALESNOTE__RATE_LIMIT_PER_MINUTE=120
SALESNOTE__REDIS_URL=redis://127.0.0.1:6379
SALESNOTE__SMTP_HOST=smtp.example.com
SALESNOTE__SMTP_PORT=587
SALESNOTE__SMTP_USERNAME=user@example.com
SALESNOTE__SMTP_PASSWORD=change-me
SALESNOTE__SMTP_FROM="Salesnote <no-reply@example.com>"
SALESNOTE__FCM_PROJECT_ID=your-project-id
SALESNOTE__FCM_KEY_JSON_PATH=service-account.json
SALESNOTE__GEOIP_URL=https://ipinfo.io/{ip}/json?token=YOUR_TOKEN
SALESNOTE__GEOIP_TOKEN=

NGINX_SERVER_NAME=your-domain.com
```

Note: Any `.env` value with spaces must be quoted, e.g.:

```bash
SALESNOTE__SEED_SHOP_NAME="Demo Shop"
SALESNOTE__SEED_SHOP_ADDRESS="12 Lagos Island Market"
```

## Security Notes
- Login lockout after repeated failures (default: 5 attempts → 15 minutes lock).
- Email outbox retries up to 2 times, then marks as `failed`.

## Redis (Rate Limit)
Rate limiting uses Redis so all API instances share the same counters. Set:

```
SALESNOTE__REDIS_URL=redis://127.0.0.1:6379
```

## Deploy (API)
Use `backend/manage.sh` on the server:

```bash
sudo bash manage.sh scale 5
```

This installs nginx/redis (if missing), registers systemd units, starts N instances on ports `8081..808N`, and reloads nginx using `nginx.conf.template`.

### Nginx + SSL
`manage.sh` reads `NGINX_SERVER_NAME` from `.env` and derives cert paths:

```
/etc/letsencrypt/live/$NGINX_SERVER_NAME/fullchain.pem
/etc/letsencrypt/live/$NGINX_SERVER_NAME/privkey.pem
```

If the certs exist, it generates HTTPS + HTTP redirect; otherwise it generates HTTP-only.

## Deploy (Worker)
Worker runs as `salesnoteworker.service` on `/home/salesnote/worker`.

## GitHub Actions
- `api-deploy.yml` builds `api` and deploys to `/home/salesnote`
- `worker-deploy.yml` builds `worker` and deploys to `/home/salesnote/worker`
