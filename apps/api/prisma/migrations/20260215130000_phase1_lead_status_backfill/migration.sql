-- Phase 1.2 backfill: map legacy lead statuses to NEW/REVIEW/APPROVED/REJECTED

UPDATE "Lead"
SET "status" = CASE
  WHEN "status" = 'OPEN' THEN 'NEW'::"LeadStatus"
  WHEN "status" = 'IN_PROGRESS' THEN 'REVIEW'::"LeadStatus"
  WHEN "status" = 'COMPLETED' THEN 'REVIEW'::"LeadStatus"
  WHEN "status" = 'CANCELLED' THEN 'REJECTED'::"LeadStatus"
  WHEN "status" = 'ASSIGNED' THEN 'APPROVED'::"LeadStatus"
  WHEN "status" = 'OFFERED' THEN 'APPROVED'::"LeadStatus"
  WHEN "status" = 'WON' THEN 'APPROVED'::"LeadStatus"
  WHEN "status" = 'LOST' THEN 'REJECTED'::"LeadStatus"
  WHEN "status" = 'ARCHIVED' THEN 'REJECTED'::"LeadStatus"
  ELSE "status"
END;

ALTER TABLE "Lead"
ALTER COLUMN "status" SET DEFAULT 'NEW'::"LeadStatus";
