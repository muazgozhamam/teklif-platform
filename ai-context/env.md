# Environment Keys (No Secret Values)

## Source of truth files checked
- `/Users/muazgozhamam/Desktop/teklif-platform/apps/api/.env` (keys only)
- `process.env.*` usage under `apps/*` and `scripts/*`

## API / Backend keys
- `DATABASE_URL`
- `PORT`
- `JWT_SECRET`
- `NODE_ENV`
- `DEV_SEED`
- `OPENAI_API_KEY`
- `OPENAI_CHAT_MODEL`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `GOOGLE_CALLBACK_URL`
- `DASHBOARD_BASE_URL`
- `OAUTH_STATE_SECRET`
- `OAUTH_ALLOWED_REDIRECTS`
- `LISTINGS_CATEGORY_CSV_PATH`
- `ADMIN_EMAIL`
- `ADMIN_PASS`
- `ALLOW_DUMMY_DB`

## Dashboard / Frontend keys
- `NEXT_PUBLIC_API_BASE_URL`
- `NEXT_PUBLIC_API_URL`
- `NEXT_PUBLIC_API_BASE`
- `API_URL`
- `NEXT_PUBLIC_APP_ENV`
- `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY`

## Admin app keys
- `API_BASE_URL`
- `NEXT_PUBLIC_API_BASE_URL`

## Ops/doc related keys
- `APP_DOMAIN`
- `API_DOMAIN`
- `APP_NAME`
- `APP_URL`

## Where set
- Local dev:
  - `apps/api/.env`
  - Optional root `.env` (read by prisma config fallback)
- Deploy env (Railway/hosting):
  - Exact UI location in platform config files: Unknown
  - Inferred by docs/scripts references in `SATDEDI_*.md` and `scripts/ops/*`

## Security rule
- Secret values must never be written into repo docs (`DATABASE_URL`, `JWT_SECRET`, provider keys, etc.).
