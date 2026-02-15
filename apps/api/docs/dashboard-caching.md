# Dashboard Caching (Phase 7.3)

## Scope
Current caching is applied to `GET /stats/me` in API service layer.

## Behavior
- Cache key: `<ROLE>:<USER_ID>`
- TTL: `DASHBOARD_STATS_CACHE_TTL_MS` (default `15000` ms)
- Cache is in-memory per API process.

## Notes
- Response shape is unchanged.
- This is an optimization layer only; no business logic change.
- In-memory cache is sufficient for local/demo and can be replaced by shared cache (Redis) in later phases.

## Validation
- `apps/api/src/stats/stats.service.spec.ts`
