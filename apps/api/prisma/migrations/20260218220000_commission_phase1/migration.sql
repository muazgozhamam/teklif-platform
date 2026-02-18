DO $$ BEGIN CREATE TYPE "CommissionCalcMethod" AS ENUM ('PERCENTAGE', 'FIXED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE "CommissionSnapshotStatus" AS ENUM ('DRAFT', 'EARNED', 'PENDING_APPROVAL', 'APPROVED', 'REVERSED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE "CommissionRole" AS ENUM ('HUNTER', 'CONSULTANT', 'BROKER', 'SYSTEM'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE "CommissionLineStatus" AS ENUM ('PENDING', 'APPROVED', 'PARTIAL', 'PAID', 'REVERSED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE "CommissionTaxModel" AS ENUM ('NONE', 'WITHHOLDING', 'VAT'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE "CommissionLedgerEntryType" AS ENUM ('EARN', 'PAYOUT', 'REVERSAL', 'ADJUSTMENT'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE "LedgerDirection" AS ENUM ('CREDIT', 'DEBIT'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE "CommissionPayoutMethod" AS ENUM ('BANK_TRANSFER', 'CASH', 'OTHER'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE "CommissionDisputeType" AS ENUM ('ATTRIBUTION', 'AMOUNT', 'ROLE', 'OTHER'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE "CommissionDisputeStatus" AS ENUM ('OPEN', 'UNDER_REVIEW', 'ESCALATED', 'RESOLVED_APPROVED', 'RESOLVED_REJECTED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE "CommissionRoundingRule" AS ENUM ('ROUND_HALF_UP', 'BANKERS'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS "CommissionPolicyVersion" (
  "id" TEXT PRIMARY KEY,
  "name" TEXT NOT NULL,
  "calcMethod" "CommissionCalcMethod" NOT NULL DEFAULT 'PERCENTAGE',
  "commissionRateBasisPoints" INTEGER,
  "fixedCommissionMinor" BIGINT,
  "currency" TEXT NOT NULL DEFAULT 'TRY',
  "hunterPercentBasisPoints" INTEGER NOT NULL,
  "consultantPercentBasisPoints" INTEGER NOT NULL,
  "brokerPercentBasisPoints" INTEGER NOT NULL,
  "systemPercentBasisPoints" INTEGER NOT NULL,
  "roundingRule" "CommissionRoundingRule" NOT NULL DEFAULT 'ROUND_HALF_UP',
  "effectiveFrom" TIMESTAMP(3) NOT NULL,
  "effectiveTo" TIMESTAMP(3),
  "isActive" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "CommissionSnapshot" (
  "id" TEXT PRIMARY KEY,
  "dealId" TEXT NOT NULL,
  "version" INTEGER NOT NULL DEFAULT 1,
  "idempotencyKey" TEXT NOT NULL,
  "status" "CommissionSnapshotStatus" NOT NULL DEFAULT 'PENDING_APPROVAL',
  "baseAmountMinor" BIGINT NOT NULL,
  "poolAmountMinor" BIGINT NOT NULL,
  "currency" TEXT NOT NULL DEFAULT 'TRY',
  "policyVersionId" TEXT NOT NULL,
  "policySnapshotJson" JSONB NOT NULL,
  "createdBy" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "approvedBy" TEXT,
  "approvedAt" TIMESTAMP(3),
  "reversedAt" TIMESTAMP(3),
  "notes" TEXT,
  CONSTRAINT "CommissionSnapshot_policyVersionId_fkey" FOREIGN KEY ("policyVersionId") REFERENCES "CommissionPolicyVersion"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "CommissionSnapshot_dealId_fkey" FOREIGN KEY ("dealId") REFERENCES "Deal"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "CommissionSnapshot_createdBy_fkey" FOREIGN KEY ("createdBy") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "CommissionSnapshot_approvedBy_fkey" FOREIGN KEY ("approvedBy") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "CommissionAllocation" (
  "id" TEXT PRIMARY KEY,
  "snapshotId" TEXT NOT NULL,
  "role" "CommissionRole" NOT NULL,
  "userId" TEXT,
  "percentBasisPoints" INTEGER NOT NULL,
  "amountMinor" BIGINT NOT NULL,
  "taxModel" "CommissionTaxModel" NOT NULL DEFAULT 'NONE',
  "taxRateBasisPoints" INTEGER NOT NULL DEFAULT 0,
  "status" "CommissionLineStatus" NOT NULL DEFAULT 'PENDING',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "CommissionAllocation_snapshotId_fkey" FOREIGN KEY ("snapshotId") REFERENCES "CommissionSnapshot"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "CommissionAllocation_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "CommissionLedgerEntry" (
  "id" TEXT PRIMARY KEY,
  "snapshotId" TEXT,
  "allocationId" TEXT,
  "dealId" TEXT NOT NULL,
  "entryType" "CommissionLedgerEntryType" NOT NULL,
  "direction" "LedgerDirection" NOT NULL,
  "amountMinor" BIGINT NOT NULL,
  "currency" TEXT NOT NULL DEFAULT 'TRY',
  "occurredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "referenceId" TEXT,
  "createdBy" TEXT NOT NULL,
  "memo" TEXT,
  CONSTRAINT "CommissionLedgerEntry_snapshotId_fkey" FOREIGN KEY ("snapshotId") REFERENCES "CommissionSnapshot"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "CommissionLedgerEntry_allocationId_fkey" FOREIGN KEY ("allocationId") REFERENCES "CommissionAllocation"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "CommissionLedgerEntry_dealId_fkey" FOREIGN KEY ("dealId") REFERENCES "Deal"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "CommissionLedgerEntry_createdBy_fkey" FOREIGN KEY ("createdBy") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "CommissionPayout" (
  "id" TEXT PRIMARY KEY,
  "payoutBatchId" TEXT,
  "paidAt" TIMESTAMP(3) NOT NULL,
  "method" "CommissionPayoutMethod" NOT NULL,
  "referenceNo" TEXT,
  "totalAmountMinor" BIGINT NOT NULL,
  "currency" TEXT NOT NULL DEFAULT 'TRY',
  "createdBy" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "CommissionPayout_createdBy_fkey" FOREIGN KEY ("createdBy") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "CommissionPayoutAllocation" (
  "id" TEXT PRIMARY KEY,
  "payoutId" TEXT NOT NULL,
  "allocationId" TEXT NOT NULL,
  "amountMinor" BIGINT NOT NULL,
  CONSTRAINT "CommissionPayoutAllocation_payoutId_fkey" FOREIGN KEY ("payoutId") REFERENCES "CommissionPayout"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "CommissionPayoutAllocation_allocationId_fkey" FOREIGN KEY ("allocationId") REFERENCES "CommissionAllocation"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "CommissionDispute" (
  "id" TEXT PRIMARY KEY,
  "dealId" TEXT NOT NULL,
  "snapshotId" TEXT,
  "openedBy" TEXT NOT NULL,
  "againstUserId" TEXT,
  "type" "CommissionDisputeType" NOT NULL,
  "status" "CommissionDisputeStatus" NOT NULL DEFAULT 'OPEN',
  "slaDueAt" TIMESTAMP(3) NOT NULL,
  "resolvedAt" TIMESTAMP(3),
  "resolvedBy" TEXT,
  "resolutionNote" TEXT,
  "evidenceMetaJson" JSONB,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "CommissionDispute_dealId_fkey" FOREIGN KEY ("dealId") REFERENCES "Deal"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "CommissionDispute_snapshotId_fkey" FOREIGN KEY ("snapshotId") REFERENCES "CommissionSnapshot"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "CommissionDispute_openedBy_fkey" FOREIGN KEY ("openedBy") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "CommissionDispute_againstUserId_fkey" FOREIGN KEY ("againstUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "CommissionDispute_resolvedBy_fkey" FOREIGN KEY ("resolvedBy") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "CommissionSnapshot_idempotencyKey_key" ON "CommissionSnapshot"("idempotencyKey");
CREATE UNIQUE INDEX IF NOT EXISTS "CommissionSnapshot_dealId_version_key" ON "CommissionSnapshot"("dealId", "version");
CREATE INDEX IF NOT EXISTS "CommissionSnapshot_status_createdAt_idx" ON "CommissionSnapshot"("status", "createdAt");
CREATE INDEX IF NOT EXISTS "CommissionPolicyVersion_effective_idx" ON "CommissionPolicyVersion"("isActive", "effectiveFrom", "effectiveTo");
CREATE INDEX IF NOT EXISTS "CommissionAllocation_snapshot_user_role_idx" ON "CommissionAllocation"("snapshotId", "userId", "role");
CREATE INDEX IF NOT EXISTS "CommissionAllocation_status_idx" ON "CommissionAllocation"("status");
CREATE INDEX IF NOT EXISTS "CommissionLedgerEntry_deal_occurredAt_idx" ON "CommissionLedgerEntry"("dealId", "occurredAt");
CREATE INDEX IF NOT EXISTS "CommissionLedgerEntry_allocation_occurredAt_idx" ON "CommissionLedgerEntry"("allocationId", "occurredAt");
CREATE INDEX IF NOT EXISTS "CommissionLedgerEntry_type_occurredAt_idx" ON "CommissionLedgerEntry"("entryType", "occurredAt");
CREATE UNIQUE INDEX IF NOT EXISTS "CommissionPayoutAllocation_payout_allocation_key" ON "CommissionPayoutAllocation"("payoutId", "allocationId");
CREATE INDEX IF NOT EXISTS "CommissionPayoutAllocation_allocationId_idx" ON "CommissionPayoutAllocation"("allocationId");
CREATE INDEX IF NOT EXISTS "CommissionDispute_status_sla_idx" ON "CommissionDispute"("status", "slaDueAt");
CREATE INDEX IF NOT EXISTS "CommissionDispute_deal_createdAt_idx" ON "CommissionDispute"("dealId", "createdAt");
