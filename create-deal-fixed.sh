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

  if (!offer) {
    console.log("ACCEPTED offer yok");
    return;
  }

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

      // 🔑 ZORUNLU ALAN
      salePrice: offer.price,
    },
  });

  console.log("✔ DEAL CREATED:", deal.id);

  await prisma.$disconnect();
})();
NODE

echo "🎯 DEAL SCRIPT COMPLETED"
