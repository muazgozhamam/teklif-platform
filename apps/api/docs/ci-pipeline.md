# CI Pipeline (Phase 8.2)

Workflow file:
- `.github/workflows/ci.yml`

## Jobs

### 1) `quality`
- `pnpm -C apps/api test`
- `pnpm -C apps/api build`
- `pnpm -C apps/dashboard lint`
- `pnpm -C apps/dashboard build`

### 2) `integration-smoke`
- Starts PostgreSQL service container.
- Creates `apps/api/.env` for CI.
- Runs:
  - `prisma migrate deploy`
  - `db:seed`
  - API startup (`pnpm -C apps/api start:dev`)
- Waits for `GET /health`.
- Executes smoke gates:
  - `scripts/smoke-admin-users.sh`
  - `scripts/smoke-stats.sh`
  - `scripts/smoke-commission-won.sh`
  - `scripts/smoke-background-jobs.sh`
  - `scripts/smoke-onboarding.sh`
  - `scripts/smoke-rbac-matrix.sh`
  - `scripts/smoke-pagination-standard.sh`
  - `scripts/smoke/smoke-pack-task45.sh` (`SMOKE_FLAG_MODE=off`, `SMOKE_ALLOC_MODE=off`)
- Stops API process with pid file cleanup (`.tmp/api-ci.pid`).

## Gate Policy
A PR is considered passing only if both jobs succeed.

## Notes
- CI uses feature flags OFF by default for network/allocation optional behaviors.
- API logs are uploaded as artifact (`api-ci-log`) on failure.
