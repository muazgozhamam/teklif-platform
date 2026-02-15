# Reputation + Trust Layer (Phase 9.4)

## Scope (v1)
- Admin trust read-model per user
- Basic trust score + risk band
- Admin review action hook (audit logged)

## Endpoints
- `GET /admin/trust/users?take=&skip=&role=&userId=`
- `POST /admin/trust/users/review?userId=`

## Scoring Inputs (v1)
- user active state
- audit event count
- login denied inactive count
- owned lead count
- consultant won deal count

## Risk Bands
- `LOW`: trustScore >= 75
- `MEDIUM`: 45..74.99
- `HIGH`: < 45

## Notes
- v1 is deterministic and read-model oriented.
- Scores are advisory and can be tuned in later phases.

## Verification
- `apps/api/src/trust/trust.service.spec.ts`
- `scripts/smoke-trust.sh`
