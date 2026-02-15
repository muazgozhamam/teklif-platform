-- Phase 1.2: Lead workflow statuses
-- Target statuses: NEW -> REVIEW -> APPROVED / REJECTED

ALTER TYPE "LeadStatus" ADD VALUE IF NOT EXISTS 'NEW';
ALTER TYPE "LeadStatus" ADD VALUE IF NOT EXISTS 'REVIEW';
ALTER TYPE "LeadStatus" ADD VALUE IF NOT EXISTS 'APPROVED';
ALTER TYPE "LeadStatus" ADD VALUE IF NOT EXISTS 'REJECTED';

-- NOTE:
-- Postgres does not allow using a newly added enum value in the same transaction.
-- Backfill/default changes are applied in the next migration.
