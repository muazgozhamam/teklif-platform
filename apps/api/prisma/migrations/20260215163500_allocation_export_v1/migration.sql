-- TASK 5.4 Allocation export v1 (backward-safe)

ALTER TABLE "CommissionAllocation"
  ADD COLUMN IF NOT EXISTS "exportedAt" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "exportBatchId" TEXT;

CREATE INDEX IF NOT EXISTS "CommissionAllocation_exportedAt_createdAt_idx"
  ON "CommissionAllocation" ("exportedAt", "createdAt");

CREATE INDEX IF NOT EXISTS "CommissionAllocation_exportBatchId_idx"
  ON "CommissionAllocation" ("exportBatchId");

DO $$ BEGIN
  ALTER TYPE "AuditAction" ADD VALUE 'COMMISSION_ALLOCATION_EXPORTED';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
