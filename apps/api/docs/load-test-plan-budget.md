# Load Test Plan + Budget (Phase 7.5)

## Objective
Define a repeatable baseline load check for critical API routes and enforce simple latency budgets.

## Scope (v1)
- Tooling: shell + curl only (no external benchmark dependency)
- Environments: local/staging
- Workload: short burst checks for core read paths

## Endpoints (baseline)
- `GET /health` (public)
- `GET /stats/me` (authenticated)
- `GET /admin/users/paged?take=20&skip=0` (authenticated admin list)

## Budget (default thresholds)
- `GET /health`: p95 <= 150ms
- `GET /stats/me`: p95 <= 500ms
- `GET /admin/users/paged`: p95 <= 700ms

These defaults are conservative for local/staging. Adjust with env vars when infra differs.

## Script
- `scripts/diag/diag-load-baseline.sh`

### Inputs
- `BASE_URL` (default `http://localhost:3001`)
- `ADMIN_EMAIL` (default `admin@local.dev`)
- `ADMIN_PASSWORD` (default `admin123`)
- `CONCURRENCY` (default `5`)
- `REQUESTS_PER_ENDPOINT` (default `40`)
- `HEALTH_P95_BUDGET_MS` (default `150`)
- `STATS_P95_BUDGET_MS` (default `500`)
- `ADMIN_USERS_P95_BUDGET_MS` (default `700`)

### Example
```bash
cd /Users/muazgozhamam/Desktop/teklif-platform
BASE_URL=http://localhost:3001 CONCURRENCY=8 REQUESTS_PER_ENDPOINT=60 ./scripts/diag/diag-load-baseline.sh
```

## Acceptance (Phase 7.5)
- Script prints p50/p95/max for each endpoint
- Script exits non-zero if any p95 budget is violated
- Results are copy-paste friendly for release notes

## Notes
- This is baseline synthetic probing, not a full production load test.
- Full load suites (k6/wrk + scenario mixes + soak) can be added in later phases.
