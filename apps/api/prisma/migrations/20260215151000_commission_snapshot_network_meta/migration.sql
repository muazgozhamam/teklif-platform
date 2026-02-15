-- TASK 4.3 network metadata hook (backward-safe)

ALTER TABLE "CommissionSnapshot"
  ADD COLUMN IF NOT EXISTS "networkMeta" JSONB;

DO $$ BEGIN
  ALTER TYPE "AuditAction" ADD VALUE 'COMMISSION_SNAPSHOT_NETWORK_CAPTURED';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
