ALTER TABLE "Lead" ADD COLUMN IF NOT EXISTS "sourceRole" TEXT;
ALTER TABLE "Lead" ADD COLUMN IF NOT EXISTS "sourceUserId" TEXT;

CREATE INDEX IF NOT EXISTS "Lead_sourceUserId_idx" ON "Lead"("sourceUserId");
CREATE INDEX IF NOT EXISTS "Lead_sourceRole_idx" ON "Lead"("sourceRole");
