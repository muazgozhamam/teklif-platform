-- TASK 4.1 Network foundation (backward-safe)

ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "parentId" TEXT;

DO $$ BEGIN
  ALTER TABLE "User"
    ADD CONSTRAINT "User_parentId_fkey"
    FOREIGN KEY ("parentId") REFERENCES "User"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS "User_parentId_idx" ON "User"("parentId");

CREATE TABLE IF NOT EXISTS "CommissionSplitConfig" (
  "id" TEXT NOT NULL,
  "role" "Role" NOT NULL,
  "percent" DOUBLE PRECISION NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "CommissionSplitConfig_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "CommissionSplitConfig_role_key" ON "CommissionSplitConfig"("role");

DO $$ BEGIN
  ALTER TYPE "AuditAction" ADD VALUE 'NETWORK_PARENT_SET';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TYPE "AuditAction" ADD VALUE 'COMMISSION_SPLIT_CONFIG_SET';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
