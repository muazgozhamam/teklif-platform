# RBAC Matrix

## Scope
This document defines role-based access control for API endpoints and the enforcement expectations.

Roles:
- `ADMIN`
- `BROKER`
- `CONSULTANT`
- `HUNTER`
- `USER` (default, low privilege)

## Enforcement Rules
- Admin endpoints must be protected with `JwtAuthGuard + RolesGuard + @Roles('ADMIN')`.
- Broker-only endpoints must be protected with `JwtAuthGuard + RolesGuard + @Roles('BROKER', 'ADMIN')` when admin override is needed.
- Consultant operations must be protected with `JwtAuthGuard + RolesGuard + @Roles('CONSULTANT', 'ADMIN')` unless explicitly broader.
- Hunter endpoints should require authentication and verify ownership in service layer where needed.
- Public endpoints must be explicitly documented and intentionally unauthenticated.

## Endpoint Matrix (Current)

| Area | Endpoint Pattern | ADMIN | BROKER | CONSULTANT | HUNTER | Notes |
|---|---|---|---|---|---|---|
| Health | `GET /health` | Allow | Allow | Allow | Allow | Public health check |
| Auth | `POST /auth/login` | Allow | Allow | Allow | Allow | Public login |
| Auth | `POST /auth/refresh` | Allow | Allow | Allow | Allow | Requires valid refresh token |
| Auth | `GET /auth/me` | Allow | Allow | Allow | Allow | Authenticated |
| Admin Users | `/admin/users*` | Allow | Deny | Deny | Deny | ADMIN only |
| Admin Commission Config | `/admin/commission-config*` | Allow | Deny | Deny | Deny | ADMIN only |
| Admin Network | `/admin/network*` | Allow | Deny | Deny | Deny | ADMIN only |
| Admin Org | `/admin/org*` | Allow | Deny | Deny | Deny | ADMIN only |
| Admin Deals | `GET /admin/deals` | Allow | Deny | Deny | Deny | ADMIN only |
| Admin Audit | `/admin/audit*` | Allow | Deny | Deny | Deny | ADMIN only |
| Admin Allocations | `/admin/allocations*` | Allow | Deny | Deny | Deny | ADMIN only |
| Broker Leads | `/broker/leads*` | Allow | Allow | Deny | Deny | BROKER + ADMIN |
| Hunter Leads | `/hunter/leads*` | Allow* | Allow* | Allow* | Allow* | Auth required; domain ownership enforced in service |
| Deals Inbox | `/deals/inbox/mine` | Allow | Deny | Allow | Deny | CONSULTANT + ADMIN |
| Deals Inbox | `/deals/inbox/pending` | Allow | Deny | Allow | Deny | CONSULTANT + ADMIN |
| Deal Status/Assign | `/deals/:id/*` | Mixed | Mixed | Mixed | Deny | Must follow per-endpoint role decorators |
| Listings | `/listings*` | Mixed | Mixed | Mixed | Deny | Multiple per-endpoint role rules |
| Stats | `GET /stats/me` | Allow | Allow | Allow | Allow | Authenticated; role-based payload |
| Commissions | `/me/commissions` | Deny | Deny | Allow | Deny | CONSULTANT only |
| Commissions | `/broker/commissions` | Allow | Allow | Deny | Deny | BROKER + ADMIN |
| Commissions | `/admin/commissions` | Allow | Deny | Deny | Deny | ADMIN only |

`Allow*` indicates route-level auth may allow multiple roles, with additional domain checks in services.

## Known Gaps / Follow-ups
- Some controllers use only `JwtAuthGuard` without explicit `@Roles(...)`; these rely on downstream domain checks.
- Add explicit route-by-route role decorators where ambiguous to reduce policy drift.
- Add CI gate for RBAC smoke to prevent accidental guard removal.

## Verification
- Runtime smoke: `scripts/smoke-rbac-matrix.sh`
- Core regression smoke pack: `scripts/smoke/restart-and-verify-api.sh`
