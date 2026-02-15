# Deploy Strategy + Migration Safety (Phase 8.4)

## Strategy (v1)
Use **rolling deploy** with strict preflight checks.

1. Preflight (must pass)
- Env validation (`diag-env-matrix`)
- Migration status check
- Recent backup check
- Build/lint/test gate

2. Migration
- Apply only backward-safe migrations (`prisma migrate deploy`)
- Never run destructive reset in deploy flow

3. App rollout
- Start new API instance(s)
- Wait for health endpoint
- Run smoke verification

4. Post-check
- Verify health + smoke
- Monitor errors for rollout window

## Rollback / Roll-forward
- Preferred: **roll-forward** with a hotfix migration/script.
- If rollback is mandatory:
  - restore latest verified backup
  - redeploy previous app version
  - run minimum smoke set

## Safety Rules
- `prisma migrate deploy` only (no `migrate reset` in shared env).
- Backup must exist before migration step.
- Deploy is blocked if preflight fails.

## Scripts
- `scripts/ops/predeploy-migration-safety.sh`
- `scripts/ops/backup-db.sh`
- `scripts/ops/drill-backup-restore.sh`
- `scripts/smoke/run-api-verification.sh`

## Suggested command
```bash
cd /Users/muazgozhamam/Desktop/teklif-platform
ENV_TARGET=staging BASE_URL=https://<staging-host> ./scripts/ops/predeploy-migration-safety.sh
```
