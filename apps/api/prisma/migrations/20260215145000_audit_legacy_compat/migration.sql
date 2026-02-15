-- Backward-compatible audit enum extension.
-- Keep legacy enum values available; do not transform existing rows.

DO $$ BEGIN
  ALTER TYPE "AuditEntityType" ADD VALUE 'COMMISSION_CONFIG';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TYPE "AuditAction" ADD VALUE 'ADMIN_USER_PATCHED';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TYPE "AuditAction" ADD VALUE 'ADMIN_COMMISSION_PATCHED';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
