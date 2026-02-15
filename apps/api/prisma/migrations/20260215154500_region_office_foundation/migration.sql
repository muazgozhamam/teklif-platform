-- TASK 4.7 Region + Office foundation (backward-safe)

CREATE TABLE IF NOT EXISTS "Region" (
  "id" TEXT NOT NULL,
  "city" TEXT NOT NULL,
  "district" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "Region_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "Region_city_idx" ON "Region"("city");
CREATE INDEX IF NOT EXISTS "Region_city_district_idx" ON "Region"("city", "district");

CREATE TABLE IF NOT EXISTS "Office" (
  "id" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "regionId" TEXT NOT NULL,
  "brokerId" TEXT,
  "overridePercent" DOUBLE PRECISION,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "Office_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "Office_regionId_idx" ON "Office"("regionId");
CREATE INDEX IF NOT EXISTS "Office_brokerId_idx" ON "Office"("brokerId");

ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "officeId" TEXT;
ALTER TABLE "Lead" ADD COLUMN IF NOT EXISTS "regionId" TEXT;

CREATE INDEX IF NOT EXISTS "User_officeId_idx" ON "User"("officeId");
CREATE INDEX IF NOT EXISTS "Lead_regionId_idx" ON "Lead"("regionId");

DO $$ BEGIN
  ALTER TABLE "Office"
    ADD CONSTRAINT "Office_regionId_fkey"
    FOREIGN KEY ("regionId") REFERENCES "Region"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "Office"
    ADD CONSTRAINT "Office_brokerId_fkey"
    FOREIGN KEY ("brokerId") REFERENCES "User"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "User"
    ADD CONSTRAINT "User_officeId_fkey"
    FOREIGN KEY ("officeId") REFERENCES "Office"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "Lead"
    ADD CONSTRAINT "Lead_regionId_fkey"
    FOREIGN KEY ("regionId") REFERENCES "Region"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TYPE "AuditEntityType" ADD VALUE 'REGION';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TYPE "AuditEntityType" ADD VALUE 'OFFICE';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TYPE "AuditAction" ADD VALUE 'REGION_CREATED';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TYPE "AuditAction" ADD VALUE 'OFFICE_CREATED';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TYPE "AuditAction" ADD VALUE 'USER_OFFICE_ASSIGNED';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TYPE "AuditAction" ADD VALUE 'LEAD_REGION_ASSIGNED';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
