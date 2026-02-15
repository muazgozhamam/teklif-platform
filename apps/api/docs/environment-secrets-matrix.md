# Environment + Secrets Matrix (Phase 8.1)

## Targets
- `local`
- `staging`
- `production`

## Variable Matrix

| Variable | Type | Secret | Local | Staging | Production | Notes |
|---|---|---|---|---|---|---|
| `DATABASE_URL` | string | YES | Required | Required | Required | Prisma datasource connection |
| `PORT` | int | NO | Optional (default `3001`) | Required | Required | API listen port |
| `JWT_SECRET` | string | YES | Recommended | Required | Required | Must not use default fallback in non-local |
| `JWT_REFRESH_SECRET` | string | YES | Recommended | Required | Required | Separate secret recommended for refresh token |
| `ACCESS_TOKEN_EXPIRES_IN` | duration | NO | Optional (default `15m`) | Recommended | Required | e.g. `15m` |
| `REFRESH_TOKEN_EXPIRES_IN` | duration | NO | Optional (default `7d`) | Recommended | Required | e.g. `7d` |
| `RATE_LIMIT_ENABLED` | bool | NO | Optional (default `1`) | Required | Required | Keep enabled in non-local |
| `RATE_LIMIT_WINDOW_MS` | int | NO | Optional (default `60000`) | Recommended | Recommended | Rate limit window |
| `RATE_LIMIT_MAX` | int | NO | Optional (default `300`) | Recommended | Recommended | Global max |
| `RATE_LIMIT_AUTH_MAX` | int | NO | Optional (default `30`) | Recommended | Recommended | Auth route max |
| `VALIDATION_STRICT_ENABLED` | bool | NO | Optional (default `1`) | Required | Required | Must stay enabled in non-local |
| `DEV_SEED` | bool | NO | Optional | Forbidden | Forbidden | Seed only for local |
| `NETWORK_COMMISSIONS_ENABLED` | bool | NO | Optional (default `0`) | Optional | Optional | Feature flag |
| `COMMISSION_ALLOCATION_ENABLED` | bool | NO | Optional (default `0`) | Optional | Optional | Feature flag |
| `DASHBOARD_STATS_CACHE_TTL_MS` | int | NO | Optional (default `15000`) | Optional | Optional | In-memory stats cache TTL |
| `BACKGROUND_JOB_RETRY_BASE_MS` | int | NO | Optional (default `200`) | Optional | Optional | Retry base delay for admin jobs |
| `APP_NAME` | string | NO | Optional | Optional | Optional | Branding/env metadata |
| `APP_DOMAIN` | string | NO | Optional | Optional | Optional | Branding/env metadata |
| `APP_URL` | string | NO | Optional | Optional | Optional | Branding/env metadata |

## Security Rules
- Never commit real secret values into repository.
- `JWT_SECRET`, `JWT_REFRESH_SECRET`, `DATABASE_URL` must be injected via secret manager in staging/production.
- Reject deployments where `JWT_SECRET` or `JWT_REFRESH_SECRET` are missing in non-local environments.
- Keep `DEV_SEED` disabled outside local.

## Verification
Use:
- `scripts/diag/diag-env-matrix.sh`

Examples:
```bash
cd /Users/muazgozhamam/Desktop/teklif-platform
ENV_TARGET=local ENV_FILE=apps/api/.env ./scripts/diag/diag-env-matrix.sh
```

```bash
cd /Users/muazgozhamam/Desktop/teklif-platform
ENV_TARGET=staging ./scripts/diag/diag-env-matrix.sh
```
