CREATE TYPE "AuditEntityType" AS ENUM ('LEAD', 'DEAL', 'LISTING', 'USER', 'COMMISSION_CONFIG');

CREATE TABLE "AuditLog" (
  "id" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "actorUserId" TEXT,
  "actorRole" TEXT,
  "action" TEXT NOT NULL,
  "entityType" "AuditEntityType" NOT NULL,
  "entityId" TEXT NOT NULL,
  "metaJson" JSONB,
  CONSTRAINT "AuditLog_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "AuditLog_entityType_entityId_createdAt_idx" ON "AuditLog"("entityType", "entityId", "createdAt");
CREATE INDEX "AuditLog_actorUserId_createdAt_idx" ON "AuditLog"("actorUserId", "createdAt");

ALTER TABLE "AuditLog"
ADD CONSTRAINT "AuditLog_actorUserId_fkey"
FOREIGN KEY ("actorUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
