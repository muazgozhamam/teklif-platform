DO $$ BEGIN
  CREATE TYPE "AuditAction" AS ENUM (
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
  ALTER TYPE "AuditEntityType" RENAME VALUE 'COMMISSION_CONFIG' TO 'COMMISSION';
EXCEPTION WHEN others THEN NULL; END $$;

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
  USING (
    CASE
      WHEN "action" = 'LEAD_CREATED' THEN 'LEAD_CREATED'::"AuditAction"
      WHEN "action" = 'LEAD_STATUS_CHANGED' THEN 'LEAD_STATUS_CHANGED'::"AuditAction"
      WHEN "action" = 'DEAL_CREATED' THEN 'DEAL_CREATED'::"AuditAction"
      WHEN "action" = 'DEAL_ASSIGNED' THEN 'DEAL_ASSIGNED'::"AuditAction"
      WHEN "action" = 'DEAL_STATUS_CHANGED' THEN 'DEAL_STATUS_CHANGED'::"AuditAction"
      WHEN "action" = 'LISTING_UPSERTED' THEN 'LISTING_UPSERTED'::"AuditAction"
      WHEN "action" = 'LISTING_PUBLISHED' THEN 'LISTING_PUBLISHED'::"AuditAction"
      WHEN "action" = 'LISTING_SOLD' THEN 'LISTING_SOLD'::"AuditAction"
      WHEN "action" = 'USER_CREATED' THEN 'USER_CREATED'::"AuditAction"
      WHEN "action" = 'USER_PATCHED' THEN 'USER_PATCHED'::"AuditAction"
      WHEN "action" = 'USER_PASSWORD_SET' THEN 'USER_PASSWORD_SET'::"AuditAction"
      WHEN "action" = 'COMMISSION_SNAPSHOT_CREATED' THEN 'COMMISSION_SNAPSHOT_CREATED'::"AuditAction"
      WHEN "action" = 'LOGIN_DENIED_INACTIVE' THEN 'LOGIN_DENIED_INACTIVE'::"AuditAction"
      WHEN "action" = 'ADMIN_USER_PATCHED' THEN 'USER_PATCHED'::"AuditAction"
      WHEN "action" = 'ADMIN_COMMISSION_PATCHED' THEN 'DEAL_STATUS_CHANGED'::"AuditAction"
      ELSE 'DEAL_STATUS_CHANGED'::"AuditAction"
    END
  );

CREATE INDEX IF NOT EXISTS "AuditLog_action_createdAt_idx" ON "AuditLog"("action", "createdAt");
CREATE INDEX IF NOT EXISTS "AuditLog_createdAt_idx" ON "AuditLog"("createdAt");
