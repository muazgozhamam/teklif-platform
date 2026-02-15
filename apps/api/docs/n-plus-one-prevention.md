# N+1 Prevention Patterns (Phase 7.2)

## Scope
This note captures the API-side N+1 discipline for list and matching workloads.

## Rules
- Avoid per-item query loops (e.g. `for (...) await prisma.*`).
- Prefer aggregated queries (`groupBy`, `in`, relation filters) over repeated `count/findUnique` calls.
- Keep list responses paginated (`take/skip`) and deterministic (`orderBy createdAt desc` unless required otherwise).
- Fetch only required fields via `select`.

## Applied in 7.2
- `MatchingService.loadByConsultant` switched from N queries (`deal.count` per consultant)
  to a single `deal.groupBy` query.
- Missing consultants in the result are explicitly backfilled with `0` load.

## Verification
- Unit tests:
  - `apps/api/src/deals/matching.service.spec.ts`
- Static scan helper:
  - `scripts/diag/diag-n-plus-one-scan.sh`

## Known Exceptions
- Tree traversal methods (network path/upline) intentionally run depth-limited lookups
  because traversal depends on the previous parent id at each level.
