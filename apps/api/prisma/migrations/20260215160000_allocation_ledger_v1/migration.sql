-- TASK 5.1 Allocation Ledger v1 (backward-safe)

DO $$ BEGIN
  CREATE TYPE "AllocationState" AS ENUM ('PENDING', 'APPROVED', 'VOID');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS "CommissionAllocation" (
  "id" TEXT NOT NULL,
  "snapshotId" TEXT NOT NULL,
  "beneficiaryUserId" TEXT NOT NULL,
  "role" "Role" NOT NULL,
  "percent" DOUBLE PRECISION NOT NULL,
  "amount" DOUBLE PRECISION NOT NULL,
  "state" "AllocationState" NOT NULL DEFAULT 'PENDING',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "CommissionAllocation_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "CommissionAllocation_snapshotId_idx"
  ON "CommissionAllocation" ("snapshotId");
CREATE INDEX IF NOT EXISTS "CommissionAllocation_beneficiaryUserId_createdAt_idx"
  ON "CommissionAllocation" ("beneficiaryUserId", "createdAt");
CREATE INDEX IF NOT EXISTS "CommissionAllocation_state_createdAt_idx"
  ON "CommissionAllocation" ("state", "createdAt");
CREATE UNIQUE INDEX IF NOT EXISTS "CommissionAllocation_snapshotId_beneficiaryUserId_role_key"
  ON "CommissionAllocation" ("snapshotId", "beneficiaryUserId", "role");

DO $$ BEGIN
  ALTER TABLE "CommissionAllocation"
    ADD CONSTRAINT "CommissionAllocation_snapshotId_fkey"
    FOREIGN KEY ("snapshotId") REFERENCES "CommissionSnapshot"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "CommissionAllocation"
    ADD CONSTRAINT "CommissionAllocation_beneficiaryUserId_fkey"
    FOREIGN KEY ("beneficiaryUserId") REFERENCES "User"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TYPE "AuditAction" ADD VALUE 'COMMISSION_ALLOCATED';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TYPE "AuditAction" ADD VALUE 'COMMISSION_ALLOCATION_APPROVED';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TYPE "AuditAction" ADD VALUE 'COMMISSION_ALLOCATION_VOIDED';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
