# KPI Engine (Phase 9.2)

## Goal
Provide admin-facing conversion funnel KPIs from existing operational entities.

## Endpoint
- `GET /admin/kpi/funnel?officeId=&regionId=`

## Response
```json
{
  "filters": { "officeId": null, "regionId": null },
  "counts": {
    "leadsTotal": 0,
    "leadsApproved": 0,
    "dealsTotal": 0,
    "listingsTotal": 0,
    "dealsWon": 0
  },
  "conversion": {
    "leadToApprovedPct": 0,
    "approvedToDealPct": 0,
    "dealToListingPct": 0,
    "listingToWonPct": 0,
    "leadToWonPct": 0
  }
}
```

## Semantics
- `leadToApprovedPct = leadsApproved / leadsTotal`
- `approvedToDealPct = dealsTotal / leadsApproved`
- `dealToListingPct = listingsTotal / dealsTotal`
- `listingToWonPct = dealsWon / listingsTotal`
- `leadToWonPct = dealsWon / leadsTotal`

Filters:
- `officeId`: restricts deal/listing counts to consultant office scope.
- `regionId`: restricts lead/deal/listing by lead region scope.

## Verification
- `apps/api/src/admin/kpi/admin-kpi.service.spec.ts`
- `scripts/smoke-kpi-funnel.sh`
