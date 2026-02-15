# Franchise Foundation (Phase 9.1)

## Goal
Provide minimum organizational hooks for franchise-style operations without changing commission math.

## Data Hooks (v1)
Using existing `Region` and `Office` models:
- Office manager assignment (`brokerId`) as office-level franchise owner hook
- Office override policy (`overridePercent`) as policy hook
- Franchise summary read-model for admin visibility

## Endpoints
- `POST /admin/org/offices/:officeId/broker`
  - body: `{ brokerId: string | null }`
  - rule: broker must be `BROKER` or `ADMIN`

- `POST /admin/org/offices/:officeId/override-policy`
  - body: `{ overridePercent: number | null }`
  - rule: `0 <= overridePercent <= 100` (or null to clear)

- `GET /admin/org/franchise/summary`
  - returns totals and region-level office policy coverage:
    - total regions/offices
    - offices with broker
    - offices with override policy

## Policy Baseline
- Broker responsibility is explicit at office level.
- Override policy is stored but not applied to payout math yet.
- Detailed franchise hierarchy and override algorithms remain future phases.

## Verification
- `scripts/smoke-franchise-foundation.sh`
