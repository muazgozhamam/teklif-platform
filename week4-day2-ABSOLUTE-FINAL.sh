#!/usr/bin/env bash
set -e

echo "==> Absolute final Deal creation (with lead connect)"

cd apps/api

node <<'NODE'
const { PrismaClient } = require("@prisma/client");

(async () => {
  const prisma = new PrismaClient();

  const offers = await prisma.offer.findMany({
    where: { status: "ACCEPTED" },
  });

  if (offers.length === 0) {
    console.log("No ACCEPTED offers found.");
    await prisma.$disconnect();
    return;
  }

  for (const offer of offers) {
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
        lead: {
          connect: { id: offer.requestId }, // 🔥 KRİTİK SATIR
        },
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
      leadId: offer.requestId,
      commissionTotal,
    });
  }

  const snapshot = await prisma.deal.findMany({
    include: {
      lead: { select: { id: true, title: true } },
      commissionEntries: true,
    },
  });

  console.log("==> DEALS SNAPSHOT");
  console.dir(snapshot, { depth: 5 });

  await prisma.$disconnect();
})();
NODE

echo ""
echo "🎯 DEAL + COMMISSION %100 TAMAMLANDI"
