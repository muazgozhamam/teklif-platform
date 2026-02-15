DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'BackgroundJobStatus') THEN
    CREATE TYPE "BackgroundJobStatus" AS ENUM ('PENDING', 'RUNNING', 'SUCCEEDED', 'FAILED');
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS "BackgroundJobRun" (
  "id" TEXT NOT NULL,
  "jobName" TEXT NOT NULL,
  "idempotencyKey" TEXT NOT NULL,
  "status" "BackgroundJobStatus" NOT NULL DEFAULT 'PENDING',
  "attempts" INTEGER NOT NULL DEFAULT 0,
  "maxAttempts" INTEGER NOT NULL DEFAULT 3,
  "payload" JSONB,
  "resultJson" JSONB,
  "lastError" TEXT,
  "startedAt" TIMESTAMP(3),
  "finishedAt" TIMESTAMP(3),
  "nextRetryAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "BackgroundJobRun_pkey" PRIMARY KEY ("id")
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'BackgroundJobRun_jobName_idempotencyKey_key'
  ) THEN
    ALTER TABLE "BackgroundJobRun"
      ADD CONSTRAINT "BackgroundJobRun_jobName_idempotencyKey_key"
      UNIQUE ("jobName", "idempotencyKey");
  END IF;
END
$$;

CREATE INDEX IF NOT EXISTS "BackgroundJobRun_jobName_status_createdAt_idx"
  ON "BackgroundJobRun"("jobName", "status", "createdAt");

CREATE INDEX IF NOT EXISTS "BackgroundJobRun_createdAt_idx"
  ON "BackgroundJobRun"("createdAt");
