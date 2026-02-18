-- CreateEnum
CREATE TYPE "ApplicationType" AS ENUM (
  'CUSTOMER_LEAD',
  'PORTFOLIO_LEAD',
  'CONSULTANT_CANDIDATE',
  'HUNTER_CANDIDATE',
  'BROKER_CANDIDATE',
  'PARTNER_CANDIDATE',
  'CORPORATE_LEAD',
  'SUPPORT_REQUEST',
  'COMPLAINT'
);

-- CreateEnum
CREATE TYPE "ApplicationPipelineStatus" AS ENUM (
  'NEW',
  'QUALIFIED',
  'IN_REVIEW',
  'MEETING_SCHEDULED',
  'APPROVED',
  'ONBOARDED',
  'REJECTED',
  'CLOSED'
);

-- CreateEnum
CREATE TYPE "ApplicationPriority" AS ENUM (
  'P0',
  'P1',
  'P2'
);

-- CreateEnum
CREATE TYPE "ApplicationEventType" AS ENUM (
  'CREATED',
  'STATUS_CHANGED',
  'ASSIGNED',
  'NOTE_ADDED',
  'TAG_ADDED',
  'TAG_REMOVED',
  'CLOSED'
);

-- CreateTable
CREATE TABLE "Application" (
  "id" TEXT NOT NULL,
  "type" "ApplicationType" NOT NULL,
  "status" "ApplicationPipelineStatus" NOT NULL DEFAULT 'NEW',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  "fullName" TEXT NOT NULL,
  "phone" TEXT NOT NULL,
  "email" TEXT,
  "city" TEXT,
  "district" TEXT,
  "notes" TEXT,
  "source" TEXT,
  "payload" JSONB,
  "assignedToUserId" TEXT,
  "priority" "ApplicationPriority" NOT NULL DEFAULT 'P2',
  "slaFirstResponseAt" TIMESTAMP(3),
  "firstResponseAt" TIMESTAMP(3),
  "lastActivityAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "tags" TEXT[] DEFAULT ARRAY[]::TEXT[],
  "dedupeKey" TEXT,

  CONSTRAINT "Application_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ApplicationNote" (
  "id" TEXT NOT NULL,
  "applicationId" TEXT NOT NULL,
  "authorUserId" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "ApplicationNote_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ApplicationEvent" (
  "id" TEXT NOT NULL,
  "applicationId" TEXT NOT NULL,
  "actorUserId" TEXT,
  "eventType" "ApplicationEventType" NOT NULL,
  "meta" JSONB,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "ApplicationEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Application_dedupeKey_key" ON "Application"("dedupeKey");

-- CreateIndex
CREATE INDEX "Application_type_status_createdAt_idx" ON "Application"("type", "status", "createdAt");
CREATE INDEX "Application_assignedToUserId_status_idx" ON "Application"("assignedToUserId", "status");
CREATE INDEX "Application_priority_createdAt_idx" ON "Application"("priority", "createdAt");
CREATE INDEX "Application_phone_idx" ON "Application"("phone");
CREATE INDEX "Application_email_idx" ON "Application"("email");

-- CreateIndex
CREATE INDEX "ApplicationNote_applicationId_createdAt_idx" ON "ApplicationNote"("applicationId", "createdAt");

-- CreateIndex
CREATE INDEX "ApplicationEvent_applicationId_createdAt_idx" ON "ApplicationEvent"("applicationId", "createdAt");
CREATE INDEX "ApplicationEvent_eventType_createdAt_idx" ON "ApplicationEvent"("eventType", "createdAt");

-- AddForeignKey
ALTER TABLE "Application"
ADD CONSTRAINT "Application_assignedToUserId_fkey"
FOREIGN KEY ("assignedToUserId") REFERENCES "User"("id")
ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ApplicationNote"
ADD CONSTRAINT "ApplicationNote_applicationId_fkey"
FOREIGN KEY ("applicationId") REFERENCES "Application"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ApplicationNote"
ADD CONSTRAINT "ApplicationNote_authorUserId_fkey"
FOREIGN KEY ("authorUserId") REFERENCES "User"("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ApplicationEvent"
ADD CONSTRAINT "ApplicationEvent_applicationId_fkey"
FOREIGN KEY ("applicationId") REFERENCES "Application"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ApplicationEvent"
ADD CONSTRAINT "ApplicationEvent_actorUserId_fkey"
FOREIGN KEY ("actorUserId") REFERENCES "User"("id")
ON DELETE SET NULL ON UPDATE CASCADE;
