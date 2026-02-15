-- Task 2.1: admin users controls + commission config

ALTER TYPE "Role" ADD VALUE IF NOT EXISTS 'BROKER';

CREATE TABLE IF NOT EXISTS "CommissionConfig" (
  "id" TEXT NOT NULL DEFAULT 'default',
  "baseRate" DOUBLE PRECISION NOT NULL DEFAULT 0.03,
  "hunterSplit" INTEGER NOT NULL DEFAULT 10,
  "brokerSplit" INTEGER NOT NULL DEFAULT 10,
  "consultantSplit" INTEGER NOT NULL DEFAULT 70,
  "platformSplit" INTEGER NOT NULL DEFAULT 10,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "CommissionConfig_pkey" PRIMARY KEY ("id")
);

INSERT INTO "CommissionConfig" ("id")
VALUES ('default')
ON CONFLICT ("id") DO NOTHING;
