-- CreateEnum
CREATE TYPE "ApplicationStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- AlterEnum
ALTER TYPE "Role" ADD VALUE 'HUNTER';

-- AlterTable
ALTER TABLE "Lead" ADD COLUMN     "sourceRole" TEXT,
ADD COLUMN     "sourceUserId" TEXT;

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "approvedAt" TIMESTAMP(3),
ADD COLUMN     "approvedByUserId" TEXT,
ADD COLUMN     "isActive" BOOLEAN NOT NULL DEFAULT false;

-- CreateTable
CREATE TABLE "HunterApplication" (
    "id" TEXT NOT NULL,
    "fullName" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "email" TEXT,
    "city" TEXT,
    "district" TEXT,
    "note" TEXT,
    "status" "ApplicationStatus" NOT NULL DEFAULT 'PENDING',
    "reviewedByUserId" TEXT,
    "reviewNote" TEXT,
    "reviewedAt" TIMESTAMP(3),
    "sponsorId" TEXT,
    "brokerId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "HunterApplication_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ConsultantCommissionProfile" (
    "id" TEXT NOT NULL,
    "consultantId" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "hunterRate" DECIMAL(65,30) NOT NULL DEFAULT 0.10,
    "brokerRate" DECIMAL(65,30) NOT NULL DEFAULT 0.10,
    "consultantRate" DECIMAL(65,30) NOT NULL DEFAULT 0.70,
    "platformRate" DECIMAL(65,30) NOT NULL DEFAULT 0.10,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ConsultantCommissionProfile_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CommissionSnapshot" (
    "id" TEXT NOT NULL,
    "dealId" TEXT NOT NULL,
    "closingPrice" DECIMAL(65,30) NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'TRY',
    "totalCommission" DECIMAL(65,30) NOT NULL,
    "hunterAmount" DECIMAL(65,30) NOT NULL,
    "brokerAmount" DECIMAL(65,30) NOT NULL,
    "consultantAmount" DECIMAL(65,30) NOT NULL,
    "platformAmount" DECIMAL(65,30) NOT NULL,
    "rateUsedJson" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CommissionSnapshot_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "HunterApplication_status_idx" ON "HunterApplication"("status");

-- CreateIndex
CREATE INDEX "HunterApplication_phone_idx" ON "HunterApplication"("phone");

-- CreateIndex
CREATE INDEX "HunterApplication_email_idx" ON "HunterApplication"("email");

-- CreateIndex
CREATE INDEX "HunterApplication_brokerId_idx" ON "HunterApplication"("brokerId");

-- CreateIndex
CREATE INDEX "HunterApplication_sponsorId_idx" ON "HunterApplication"("sponsorId");

-- CreateIndex
CREATE UNIQUE INDEX "ConsultantCommissionProfile_consultantId_key" ON "ConsultantCommissionProfile"("consultantId");

-- CreateIndex
CREATE INDEX "ConsultantCommissionProfile_consultantId_isActive_idx" ON "ConsultantCommissionProfile"("consultantId", "isActive");

-- CreateIndex
CREATE UNIQUE INDEX "CommissionSnapshot_dealId_key" ON "CommissionSnapshot"("dealId");

-- AddForeignKey
ALTER TABLE "ConsultantCommissionProfile" ADD CONSTRAINT "ConsultantCommissionProfile_consultantId_fkey" FOREIGN KEY ("consultantId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommissionSnapshot" ADD CONSTRAINT "CommissionSnapshot_dealId_fkey" FOREIGN KEY ("dealId") REFERENCES "Deal"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
