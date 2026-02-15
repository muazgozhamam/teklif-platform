# Backup + Restore Drill (Phase 8.3)

## Objective
Provide deterministic, repeatable database backup and restore operations for local/staging.

## Scripts
- `scripts/ops/backup-db.sh`
- `scripts/ops/restore-db.sh`
- `scripts/ops/drill-backup-restore.sh`

## Preconditions
- `DATABASE_URL` is available (env or `apps/api/.env`)
- PostgreSQL client tools installed (`pg_dump`, `pg_restore`, `psql`)

## Backup
```bash
cd /Users/muazgozhamam/Desktop/teklif-platform
DATABASE_URL='postgresql://user:pass@host:5432/db?schema=public' ./scripts/ops/backup-db.sh
```

Output:
- `./backups/teklif-YYYYMMDD-HHMMSS.dump`

## Restore
```bash
cd /Users/muazgozhamam/Desktop/teklif-platform
DATABASE_URL='postgresql://user:pass@host:5432/db?schema=public' BACKUP_FILE=./backups/teklif-YYYYMMDD-HHMMSS.dump ./scripts/ops/restore-db.sh
```

## Drill (non-destructive by default)
```bash
cd /Users/muazgozhamam/Desktop/teklif-platform
DATABASE_URL='postgresql://user:pass@host:5432/db?schema=public' ./scripts/ops/drill-backup-restore.sh
```

- Default drill performs:
  - backup creation
  - backup listing
  - restore dry-run capability check
- Full restore requires `RESTORE_ON_DRILL=1`.

## Safety Rules
- Never restore into production without explicit maintenance window.
- Always validate target DB before restore.
- Keep multiple backup generations; do not overwrite previous dumps.

## Acceptance
- Backup script creates dump successfully.
- Restore script validates input and DB reachability.
- Drill script exits non-zero on any failed step.
