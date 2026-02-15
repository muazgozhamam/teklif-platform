# Gamification (Phase 9.3)

## Scope (v1)
- Role-based point profile for current user
- Admin leaderboard by role
- Badge/tier projection from existing operational data (no schema change)

## Endpoints
- `GET /gamification/me`
- `GET /admin/gamification/leaderboard?role=HUNTER|CONSULTANT|BROKER&take=&skip=`

## Tiers
- `BRONZE` `<100`
- `SILVER` `100..299`
- `GOLD` `300..599`
- `PLATINUM` `>=600`

## Notes
- v1 is read-model only.
- Points and badge rules are deterministic and can be tuned in later phases.

## Verification
- `apps/api/src/gamification/gamification.service.spec.ts`
- `scripts/smoke-gamification.sh`
