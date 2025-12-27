#!/usr/bin/env bash
set -e

cd apps/api

node <<'NODE'
const { PrismaClient } = require("@prisma/client");

(async () => {
  const prisma = new PrismaClient();

  const user = await prisma.user.findFirst();
  if (!user) throw new Error("User yok");

  const offer = await prisma.offer.findFirst({
    where: { status: "ACCEPTED" },
  });
  if (!offer) throw new Error("ACCEPTED offer yok");

  const salePrice = offer.price;
  const commissionRate = offer.commissionRate ?? 0.02;
  const commissionTotal = salePrice * commissionRate;

  const exists = await prisma.deal.findUnique({
    where: { leadId: offer.requestId },
  });

  if (exists) {
    console.log("Deal zaten var");
    return;
  }

  const deal = await prisma.deal.create({
    data: {
      lead: { connect: { id: offer.requestId } },
      createdBy: { connect: { id: user.id } },
      status: "ACTIVE",

      salePrice,
      commissionTotal,
    },
  });

  console.log("✔ DEAL CREATED:", deal.id);
  console.log("💰 commissionTotal:", commissionTotal);

  await prisma.$disconnect();
})();
NODE

echo "🎯 DEAL FINAL SCRIPT COMPLETED"
