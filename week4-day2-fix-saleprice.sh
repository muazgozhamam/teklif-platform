#!/usr/bin/env bash
set -e

echo "==> Fixing Deal creation: adding salePrice"

cd apps/api

node <<'NODE'
const { PrismaClient } = require("@prisma/client");

(async () => {
  const prisma = new PrismaClient();

  const acceptedOffers = await prisma.offer.findMany({
    where: { status: "ACCEPTED" },
  });

  for (const offer of acceptedOffers) {
    const existing = await prisma.deal.findUnique({
      where: { leadId: offer.requestId },
    });

    if (existing) {
      console.log("ℹ️ Deal already exists for lead:", offer.requestId);
      continue;
    }

    const deal = await prisma.deal.create({
      data: {
        leadId: offer.requestId,
        offerId: offer.id,
        price: offer.price,
        salePrice: offer.price, // 🔴 FIX BURASI
        commissionRate: 0.02,
      },
    });

    await prisma.commissionEntry.create({
      data: {
        dealId: deal.id,
        amount: offer.price * 0.02,
        description: "Broker commission (%2)",
      },
    });

    console.log("✔ Deal created:", {
      dealId: deal.id,
      salePrice: deal.salePrice,
    });
  }

  const snapshot = await prisma.deal.findMany({
    include: { commissionEntries: true },
  });

  console.log("==> DEALS SNAPSHOT");
  console.dir(snapshot, { depth: 5 });

  await prisma.$disconnect();
})();
NODE

echo ""
echo "🎯 Day4–Adım2 FIX COMPLETED"
