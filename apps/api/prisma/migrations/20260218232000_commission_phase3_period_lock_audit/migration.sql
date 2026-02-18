DO $$ BEGIN CREATE TYPE "CommissionAuditAction" AS ENUM (
  'SNAPSHOT_CREATED',
  'SNAPSHOT_APPROVED',
  'SNAPSHOT_REVERSED',
  'PAYOUT_CREATED',
  'DISPUTE_CREATED',
  'DISPUTE_STATUS_CHANGED',
  'PERIOD_LOCK_CREATED',
  'PERIOD_LOCK_RELEASED',
  'DISPUTE_ESCALATED'
); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE "CommissionAuditEntityType" AS ENUM ('SNAPSHOT','PAYOUT','DISPUTE','PERIOD_LOCK','SYSTEM'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS "CommissionPeriodLock" (
  "id" TEXT PRIMARY KEY,
  "periodFrom" TIMESTAMP(3) NOT NULL,
  "periodTo" TIMESTAMP(3) NOT NULL,
  "reason" TEXT NOT NULL,
  "isActive" BOOLEAN NOT NULL DEFAULT true,
  "createdBy" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "unlockedBy" TEXT,
  "unlockedAt" TIMESTAMP(3),
  CONSTRAINT "CommissionPeriodLock_createdBy_fkey" FOREIGN KEY ("createdBy") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "CommissionPeriodLock_unlockedBy_fkey" FOREIGN KEY ("unlockedBy") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "CommissionAuditEvent" (
  "id" TEXT PRIMARY KEY,
  "action" "CommissionAuditAction" NOT NULL,
  "entityType" "CommissionAuditEntityType" NOT NULL,
  "entityId" TEXT,
  "actorUserId" TEXT,
  "payloadJson" JSONB,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "CommissionAuditEvent_actorUserId_fkey" FOREIGN KEY ("actorUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "CommissionPeriodLock_active_period_idx" ON "CommissionPeriodLock"("isActive", "periodFrom", "periodTo");
CREATE INDEX IF NOT EXISTS "CommissionAuditEvent_action_createdAt_idx" ON "CommissionAuditEvent"("action", "createdAt");
CREATE INDEX IF NOT EXISTS "CommissionAuditEvent_entity_idx" ON "CommissionAuditEvent"("entityType", "entityId");
