DO $$ BEGIN
  CREATE TYPE "PrivacyMode" AS ENUM ('EXACT', 'APPROXIMATE', 'HIDDEN');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE "AttributeType" AS ENUM ('TEXT', 'NUMBER', 'BOOLEAN', 'SELECT', 'MULTISELECT');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "createdById" TEXT;
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "categoryLeafId" TEXT;
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "categoryPathKey" TEXT;
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "priceAmount" DECIMAL(18,2);
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "neighborhood" TEXT;
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "lat" DOUBLE PRECISION;
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "lng" DOUBLE PRECISION;
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "privacyMode" "PrivacyMode" NOT NULL DEFAULT 'EXACT';
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "sahibindenUrl" TEXT;
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "exportedAt" TIMESTAMP(3);
ALTER TABLE "Listing" ADD COLUMN IF NOT EXISTS "exportedById" TEXT;

CREATE TABLE IF NOT EXISTS "CategoryNode" (
  "id" TEXT NOT NULL,
  "parentId" TEXT,
  "name" TEXT NOT NULL,
  "slug" TEXT NOT NULL,
  "depth" INTEGER NOT NULL,
  "order" INTEGER NOT NULL DEFAULT 0,
  "isActive" BOOLEAN NOT NULL DEFAULT true,
  "pathKey" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "CategoryNode_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "CategoryNode_pathKey_key" ON "CategoryNode"("pathKey");
CREATE INDEX IF NOT EXISTS "CategoryNode_parentId_order_idx" ON "CategoryNode"("parentId","order");
CREATE INDEX IF NOT EXISTS "CategoryNode_depth_isActive_idx" ON "CategoryNode"("depth","isActive");

CREATE TABLE IF NOT EXISTS "AttributeDefinition" (
  "id" TEXT NOT NULL,
  "categoryLeafId" TEXT NOT NULL,
  "key" TEXT NOT NULL,
  "label" TEXT NOT NULL,
  "type" "AttributeType" NOT NULL,
  "required" BOOLEAN NOT NULL DEFAULT false,
  "optionsJson" JSONB,
  "order" INTEGER NOT NULL DEFAULT 0,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "AttributeDefinition_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "AttributeDefinition_categoryLeafId_key_key" ON "AttributeDefinition"("categoryLeafId","key");
CREATE INDEX IF NOT EXISTS "AttributeDefinition_categoryLeafId_order_idx" ON "AttributeDefinition"("categoryLeafId","order");

CREATE TABLE IF NOT EXISTS "ListingAttribute" (
  "id" TEXT NOT NULL,
  "listingId" TEXT NOT NULL,
  "key" TEXT NOT NULL,
  "valueJson" JSONB NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ListingAttribute_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "ListingAttribute_listingId_key_key" ON "ListingAttribute"("listingId","key");
CREATE INDEX IF NOT EXISTS "ListingAttribute_listingId_idx" ON "ListingAttribute"("listingId");

CREATE INDEX IF NOT EXISTS "Listing_status_categoryLeafId_city_district_idx" ON "Listing"("status","categoryLeafId","city","district");
CREATE INDEX IF NOT EXISTS "Listing_lat_lng_idx" ON "Listing"("lat","lng");

DO $$ BEGIN
  ALTER TABLE "CategoryNode"
  ADD CONSTRAINT "CategoryNode_parentId_fkey"
  FOREIGN KEY ("parentId") REFERENCES "CategoryNode"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "AttributeDefinition"
  ADD CONSTRAINT "AttributeDefinition_categoryLeafId_fkey"
  FOREIGN KEY ("categoryLeafId") REFERENCES "CategoryNode"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "ListingAttribute"
  ADD CONSTRAINT "ListingAttribute_listingId_fkey"
  FOREIGN KEY ("listingId") REFERENCES "Listing"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "Listing"
  ADD CONSTRAINT "Listing_createdById_fkey"
  FOREIGN KEY ("createdById") REFERENCES "User"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "Listing"
  ADD CONSTRAINT "Listing_exportedById_fkey"
  FOREIGN KEY ("exportedById") REFERENCES "User"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "Listing"
  ADD CONSTRAINT "Listing_categoryLeafId_fkey"
  FOREIGN KEY ("categoryLeafId") REFERENCES "CategoryNode"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

