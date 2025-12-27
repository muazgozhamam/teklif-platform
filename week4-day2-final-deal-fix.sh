#!/usr/bin/env bash
set -e

echo "==> Final Deal + Commission fix (salePrice + commissionTotal)"

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
    const exists = await prisma.deal.findUnique({
      where: { leadId: offer.requestId },
    });

    if (exists) {
      console.log("ℹ️ Deal already exists for lead:", offer.requestId);
      continue;
    }

    const salePrice = offer.price;
    const commissionRate = 0.02;
    const commissionTotal = salePrice * commissionRate;

    const deal = await prisma.deal.create({
      data: {
        leadId: offer.requestId,
        offerId: offer.id,
        price: offer.price,
        salePrice,
        commissionRate,
        commissionTotal,
      },
    });

    await prisma.commissionEntry.create({
      data: {
        dealId: deal.id,
        amount: commissionTotal,
        description: "Broker commission (%2)",
      },
    });

    console.log("✔ Deal created:", {
      dealId: deal.id,
      salePrice,
      commissionTotal,
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
echo "🎯 Day4–Adım2 COMPLETELY DONE"
