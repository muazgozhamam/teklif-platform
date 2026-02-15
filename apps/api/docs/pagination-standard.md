# Pagination Standard (Phase 7.1)

## Canonical Contract
List endpoints should return:

```json
{
  "items": [],
  "total": 0,
  "take": 20,
  "skip": 0
}
```

Rules:
- `take` default: 20 (or endpoint-specific safe default)
- `take` max: 100
- `skip` min: 0
- Sort should be deterministic (usually `createdAt desc`)

## Backward Compatibility
Some existing endpoints also expose legacy fields. They are kept to avoid breaking clients:
- `GET /broker/leads/pending/paged`: keeps `page` and `limit`, now also returns `take` and `skip`
- `GET /listings`: keeps `page` and `pageSize`, now also returns `take` and `skip`
- `GET /admin/users`: unchanged legacy array response
- `GET /admin/users/paged`: new canonical paginated response

## Endpoints Aligned in 7.1
- `GET /admin/users/paged`
- `GET /admin/deals`
- `GET /admin/audit`
- `GET /admin/allocations`
- `GET /admin/commissions`
- `GET /broker/commissions`
- `GET /me/commissions`
- `GET /deals/inbox/pending`
- `GET /deals/inbox/mine`
- `GET /broker/leads/pending/paged` (hybrid)
- `GET /listings` (hybrid)

## Validation
- Script: `scripts/smoke-pagination-standard.sh`
