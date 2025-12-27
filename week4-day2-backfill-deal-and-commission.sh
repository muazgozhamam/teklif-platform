#!/usr/bin/env bash
set -e

echo "==> Backfilling Deal + CommissionEntry for ACCEPTED offers"

cd apps/api

node <<'NODE'
const { PrismaClient } = require("@prisma/client");

(async () => {
  const prisma = new PrismaClient();

  const acceptedOffers = await prisma.offer.findMany({
    where: { status: "ACCEPTED" },
  });

  if (acceptedOffers.length === 0) {
    console.log("No ACCEPTED offers found.");
    await prisma.$disconnect();
    return;
  }

  for (const offer of acceptedOffers) {
    const existingDeal = await prisma.deal.findUnique({
      where: { leadId: offer.requestId },
    });

    if (existingDeal) {
      console.log("ℹ️ Deal already exists for lead:", offer.requestId);
      continue;
    }

    const deal = await prisma.deal.create({
      data: {
        leadId: offer.requestId,
        offerId: offer.id,
        price: offer.price,
        commissionRate: 0.02,
      },
    });

    const commission = await prisma.commissionEntry.create({
      data: {
        dealId: deal.id,
        amount: offer.price * 0.02,
        description: "Broker commission (%2)",
      },
    });

    console.log("✔ Deal created:", {
      dealId: deal.id,
      leadId: offer.requestId,
      commission: commission.amount,
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
echo "🎯 Day4–Adım2 COMPLETED (Backfill mode)"
