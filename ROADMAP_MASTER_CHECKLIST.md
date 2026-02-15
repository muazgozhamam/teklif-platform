# ROADMAP_MASTER_CHECKLIST

| Item ID | Status | Owner | Evidence | Notes |
|---|---|---|---|---|
| 1.1 Role/Guard stabilization | DONE |  | `scripts/smoke-consultant-inbox-listing.sh` | Core role-based flow stabilized in prior tasks |
| 1.2 Lead lifecycle | DONE |  | `scripts/smoke-broker-approve-to-listing.sh` | NEW/REVIEW/APPROVED/REJECTED flow operational |
| 1.3 Deal lifecycle | DONE |  | `scripts/smoke-broker-approve-to-listing.sh` | Assign/status flow active |
| 1.4 Listing pipeline | DONE |  | `scripts/smoke-consultant-inbox-listing.sh` | Deal->Listing upsert validated |
| 1.5 Deterministic E2E smoke | DONE |  | `scripts/smoke/run-api-verification.sh` | Repeatable smoke orchestration exists |
| 2.1 Admin panel core | DONE |  | `scripts/smoke-admin-users.sh` | Users/roles/isActive/commission config functional |
| 2.2 Dashboard metrics baseline | DONE |  | `scripts/smoke-stats.sh` | `/stats/me` role payloads validated |
| 2.3 Audit/timeline contract | DONE |  | `apps/api/src/audit/audit-normalization.spec.ts` | Raw+canonical + alias-safe filtering |
| 3.1 Commission config model | DONE |  | `scripts/smoke-admin-users.sh` | Config read/update active |
| 3.2 Snapshot generation on WON | DONE |  | `scripts/smoke-commission-won.sh` | Idempotent snapshot on WON |
| 3.3 Commission reports endpoints | DONE |  | `scripts/smoke-commission-reports.sh` | Consultant/Broker/Admin reports live |
| 3.4 Snapshot immutability rules | DONE |  | `scripts/smoke-commission-won.sh` | Duplicate snapshot prevented |
| 3.5 Commission audit BC mapping | DONE |  | `apps/api/src/audit/audit-normalization.spec.ts` | Legacy-to-canonical semantics maintained |
| 4.1 User hierarchy foundation | DONE |  | `scripts/smoke/smoke-network-foundation.sh` | parent/path/upline operational |
| 4.2 CommissionSplitConfig mgmt | DONE |  | `scripts/smoke/smoke-network-foundation.sh` | Admin split set/get operational |
| 4.3 Region+Office foundation | DONE |  | `scripts/smoke/smoke-pack-task45.sh` | Region/office create/assign validated |
| 4.4 Office/Region scoping filters | DONE |  | `scripts/smoke/smoke-pack-task45.sh` | Optional filters active |
| 4.5 Trace metadata flagged | DONE |  | `scripts/smoke/smoke-pack-task45.sh` | networkMeta/splitTrace/officeTrace checks |
| 4.6 Performance indexes + diag | DONE |  | `scripts/diag/diag-query-plans.sh` | Query plan sanity tooling exists |
| 5.1 CommissionAllocation model | DONE |  | `apps/api/src/allocations/allocations.service.spec.ts` | Ledger model active |
| 5.2 Allocation generation v1 | DONE |  | `apps/api/src/allocations/allocations.service.spec.ts` | Safe identity allocation in place |
| 5.3 Approve/Void workflow | DONE |  | `apps/api/src/allocations/allocations.service.spec.ts` | State transitions + audit covered |
| 5.4 Payout export CSV | DONE |  | `scripts/smoke/smoke-pack-task45.sh` | `GET /admin/allocations/export.csv` + `POST /admin/allocations/export/mark` added |
| 5.5 Financial integrity invariants | DONE |  | `scripts/smoke/smoke-pack-task45.sh` | Invariants: snapshot math, allocation-vs-consultant sum, export batch integrity + immutability guards |
| 6.1 Auth hardening (expiry/refresh) | DONE |  | `scripts/smoke-auth-refresh.sh` | Runtime smoke passed (login -> refresh -> auth/me) |
| 6.2 Rate limiting | DONE |  | `scripts/smoke-rate-limit.sh` | Runtime smoke passed (429 observed after auth limit threshold) |
| 6.3 Input validation strictness | DONE |  | `scripts/smoke-validation-strict.sh` | Runtime smoke passed (unknown field rejected under strict validation) |
| 6.4 Audit tamper-evidence | DONE |  | `scripts/smoke-audit-integrity.sh` | Runtime smoke passed (hash-chain integrity endpoint healthy) |
| 6.5 RBAC matrix documentation | DONE |  | `apps/api/docs/rbac-matrix.md`, `scripts/smoke-rbac-matrix.sh` | RBAC matrix documented and role-access smoke script added |
| 7.1 Pagination standards | DONE |  | `apps/api/docs/pagination-standard.md`, `scripts/smoke-pagination-standard.sh` | Runtime smoke passed; canonical pagination contract active with backward-compatible hybrid responses |
| 7.2 N+1 prevention patterns | DONE |  | `apps/api/src/deals/matching.service.spec.ts`, `apps/api/docs/n-plus-one-prevention.md`, `scripts/diag/diag-n-plus-one-scan.sh` | Matching load query collapsed to single groupBy; unit tests + static scan passed |
| 7.3 Dashboard caching | DONE |  | `apps/api/src/stats/stats.service.spec.ts`, `apps/api/docs/dashboard-caching.md`, `scripts/smoke-stats.sh` | Runtime stats smoke passed after cache layer; response contract unchanged |
| 7.4 Background jobs + idempotency | DONE |  | `apps/api/src/admin/jobs/admin-jobs.service.ts`, `apps/api/src/admin/jobs/admin-jobs.service.spec.ts`, `scripts/smoke-background-jobs.sh` | Runtime smoke passed; idempotent job-run model + retry policy active |
| 7.5 Load testing plan + budget | DONE |  | `apps/api/docs/load-test-plan-budget.md`, `scripts/diag/diag-load-baseline.sh` | Runtime baseline load diag passed with budget checks |
| 8.1 Environment/secrets matrix | DONE |  | `apps/api/docs/environment-secrets-matrix.md`, `scripts/diag/diag-env-matrix.sh` | Matrix documented; local env validation diag executed |
| 8.2 CI pipeline full gate | DONE |  | `.github/workflows/ci.yml`, `apps/api/docs/ci-pipeline.md` | Quality + integration-smoke gates expanded (admin/stats/commission/background-jobs/onboarding/rbac/pagination/smoke-pack) with API lifecycle cleanup |
| 8.3 Backup + restore drills | DONE |  | `apps/api/docs/backup-restore-drill.md`, `scripts/ops/backup-db.sh`, `scripts/ops/restore-db.sh`, `scripts/ops/drill-backup-restore.sh` | Runtime drill passed (backup created, latest backup verified, safe restore skip confirmed) |
| 8.4 Deploy strategy + migration safety | DONE |  | `apps/api/docs/deploy-migration-safety.md`, `scripts/ops/predeploy-migration-safety.sh` | Runtime predeploy safety gate passed (env/build/lint/migration/backup/health/smoke) |
| 8.5 Observability + alerting | DONE |  | `apps/api/docs/observability-alerting.md`, `scripts/diag/diag-observability.sh`, `apps/api/src/health/health.controller.ts` | Runtime observability diag passed; `/health/metrics` and baseline alert thresholds active |
| 9.1 Franchise foundation | DONE |  | `apps/api/docs/franchise-foundation.md`, `scripts/smoke-franchise-foundation.sh`, `apps/api/src/admin/org/admin-org.controller.ts` | Runtime franchise smoke passed; office broker/policy hooks + summary read-model active |
| 9.2 KPI engine | DONE |  | `apps/api/src/admin/kpi/admin-kpi.service.ts`, `apps/api/docs/kpi-engine.md`, `scripts/smoke-kpi-funnel.sh` | Runtime KPI smoke passed; admin funnel endpoint active with optional scoping |
| 9.3 Gamification | DONE |  | `apps/api/src/gamification/gamification.service.ts`, `apps/api/docs/gamification.md`, `scripts/smoke-gamification.sh` | Runtime gamification smoke passed; profile + leaderboard endpoints active |
| 9.4 Reputation/trust layer | DONE |  | `apps/api/src/trust/trust.service.ts`, `apps/api/docs/reputation-trust.md`, `scripts/smoke-trust.sh` | Runtime trust smoke passed; risk read-model + review hook active |
| 9.5 Partner onboarding ops | DONE |  | `apps/api/docs/partner-onboarding-ops.md`, `scripts/smoke-onboarding.sh` | Runtime smoke passed: `/onboarding/me` and `/admin/onboarding/users` |
| 10.1 Frontend role-based shell + auth guard | DONE |  | `apps/dashboard/middleware.ts`, `apps/dashboard/lib/auth.ts`, `apps/dashboard/lib/roles.ts`, `apps/dashboard/lib/session.ts` | Role mismatch redirect now lands on correct role home; auth helpers standardized |
| 10.2 Frontend global loading/error/not-found | DONE |  | `apps/dashboard/app/loading.tsx`, `apps/dashboard/app/global-error.tsx`, `apps/dashboard/app/not-found.tsx` | Global fallback states standardized |
| 10.3 Frontend role landing + KPI read-only | DONE |  | `apps/dashboard/app/admin/page.tsx`, `apps/dashboard/app/broker/page.tsx`, `apps/dashboard/app/consultant/page.tsx` | Admin/Broker/Consultant landing pages show role metrics from `/stats/me` |
| 10.4 Frontend smoke + demo pack | DONE |  | `scripts/smoke-frontend-phase1.sh`, `FRONTEND_PHASE1_DEMO.md` | Runtime smoke passed on local (`smoke-frontend-phase1 OK`) |
