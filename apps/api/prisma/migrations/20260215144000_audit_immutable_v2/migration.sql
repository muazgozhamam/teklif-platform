DO $$ BEGIN
  CREATE TYPE "AuditAction" AS ENUM (
    'ADMIN_USER_PATCHED',
    'ADMIN_COMMISSION_PATCHED',
    'LEAD_CREATED',
    'LEAD_STATUS_CHANGED',
    'DEAL_CREATED',
    'DEAL_ASSIGNED',
    'DEAL_STATUS_CHANGED',
    'LISTING_UPSERTED',
    'LISTING_PUBLISHED',
    'LISTING_SOLD',
    'USER_CREATED',
    'USER_PATCHED',
    'USER_PASSWORD_SET',
    'COMMISSION_SNAPSHOT_CREATED',
    'LOGIN_DENIED_INACTIVE'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TYPE "AuditEntityType" ADD VALUE 'COMMISSION';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TYPE "AuditEntityType" ADD VALUE 'AUTH';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE "AuditLog"
  ADD COLUMN IF NOT EXISTS "beforeJson" JSONB,
  ADD COLUMN IF NOT EXISTS "afterJson" JSONB;

ALTER TABLE "AuditLog"
  ALTER COLUMN "actorRole" TYPE "Role"
  USING (
    CASE
      WHEN "actorRole" IN ('USER','ADMIN','BROKER','CONSULTANT','HUNTER') THEN "actorRole"::"Role"
      ELSE NULL
    END
  );

ALTER TABLE "AuditLog"
  ALTER COLUMN "action" TYPE "AuditAction"
  USING ("action"::text::"AuditAction");

CREATE INDEX IF NOT EXISTS "AuditLog_action_createdAt_idx" ON "AuditLog"("action", "createdAt");
CREATE INDEX IF NOT EXISTS "AuditLog_createdAt_idx" ON "AuditLog"("createdAt");
