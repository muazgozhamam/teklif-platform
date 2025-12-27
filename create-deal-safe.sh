#!/usr/bin/env bash
set -e

cd apps/api

node <<'NODE'
const { PrismaClient } = require("@prisma/client");

(async () => {
  const prisma = new PrismaClient();

  const offer = await prisma.offer.findFirst({
    where: { status: "ACCEPTED" },
  });
  if (!offer) throw new Error("ACCEPTED offer yok");

  const lead = await prisma.lead.findUnique({
    where: { id: offer.requestId },
  });
  if (!lead) {
    console.error("❌ Lead bulunamadı:", offer.requestId);
    return;
  }

  const user = await prisma.user.findFirst();
  if (!user) throw new Error("User yok");

  const salePrice = offer.price;
  const commissionRate = offer.commissionRate ?? 0.02;
  const commissionTotal = salePrice * commissionRate;

  const existing = await prisma.deal.findUnique({
    where: { leadId: lead.id },
  });

  if (existing) {
    console.log("⚠️ Deal zaten var:", existing.id);
    return;
  }

  const deal = await prisma.deal.create({
    data: {
      lead: { connect: { id: lead.id } },
      createdBy: { connect: { id: user.id } },
      status: "ACTIVE",
      salePrice,
      commissionTotal,
    },
  });

  console.log("✅ DEAL CREATED:", deal.id);
  console.log("Lead:", lead.id);
  console.log("Commission:", commissionTotal);

  await prisma.$disconnect();
})();
NODE

echo "🎯 DEAL SAFE SCRIPT COMPLETED"
