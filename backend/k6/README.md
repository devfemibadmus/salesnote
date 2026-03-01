# k6 Local Load Testing

This folder is for local API load testing before you spend money on a VM.

## What is here

Main dedicated scripts:

- `login-only.js`: login only
- `home-gets.js`: `/home`, `/analytics/summary`, `/shop`, `/settings`
- `sales-list.js`: sales list only
- `item-list.js`: sales list with `include_items=true` (item-list equivalent)
- `sales-create.js`: sales creation only

## Before you run it

1. Start the API locally.
2. Make sure local PostgreSQL and Redis are running.
3. Create at least one shop account.
4. Edit [local.config.js](/c:/Users/Femi.Badmus/Desktop/Sales%20Note/backend/k6/local.config.js) once with your local login details.

If you want sample local data first, use your existing seed flow:

```powershell
cd backend
cargo run --bin seed
```

## Local config

Main config file:

- [local.config.js](/c:/Users/Femi.Badmus/Desktop/Sales%20Note/backend/k6/local.config.js)

Default fields inside it:

- `baseUrl`
- `loginId`
- `password`
- `vus`
- `duration`
- `executionMode` (`duration` or `iterations`)
- `perVuIterations`
- `thinkTimeSecs`
- `includeItems`
- `signatureName`
- `signatureImageUrl`

You no longer need to set PowerShell env vars for normal local runs.

If you want an exact number of runs per user, set in [local.config.js](/c:/Users/Femi.Badmus/Desktop/Sales%20Note/backend/k6/local.config.js):

```js
executionMode: 'iterations',
perVuIterations: 20,
vus: 10,
```

That means:

- `10` users
- `20` full iterations each
- total `200` iterations

Optional:

- `BASE_URL`: default is `http://127.0.0.1:8080`
- `VUS`: virtual users, default `10`
- `DURATION`: default `30s`
- `THINK_TIME_SECS`: default `1`
- `SIGNATURE_NAME`: default `Amanda`
- `SIGNATURE_IMAGE_URL`: default seed signature image URL

## Windows PowerShell examples

Login only:

```powershell
k6 run backend/k6/login-only.js
```

Home GETs:

```powershell
k6 run backend/k6/home-gets.js
```

Sales list:

```powershell
k6 run backend/k6/sales-list.js
```

Item list:

```powershell
k6 run backend/k6/item-list.js
```

Sales create:

```powershell
k6 run backend/k6/sales-create.js
```

If you want to override the local file temporarily, env vars still win:

```powershell
$env:LOGIN_ID="another@example.com"
$env:LOGIN_PASSWORD="another-password"
k6 run backend/k6/login-only.js
```

If no signature exists, `sales-create.js` will:

1. download `SIGNATURE_IMAGE_URL`
2. upload it to `/signatures`
3. continue with sale creation

## What to look at

For local testing, focus on:

1. `http_req_duration`
2. `http_req_failed`
3. p95 latency
4. whether `sales-create.js` starts failing under small load

If `sales-create.js` breaks early locally, do not size a VM yet. Fix the bottleneck first.
