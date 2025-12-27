#!/usr/bin/env bash
set -e

echo "==> Final Deal creation with createdBy + lead"

cd apps/api

node <<'NODE'
const { PrismaClient } = require("@prisma/client");

(async () => {
  const prisma = new PrismaClient();

  // 1) System user (any existing user)
  const systemUser = await prisma.user.findFirst();
  if (!systemUser) {
    throw new Error("No User found. At least one User is required.");
  }

  console.log("Using system user:", systemUser.id);

  // 2) Accepted offers
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
          connect: { id: offer.requestId },
        },
        createdBy: {
          connect: { id: systemUser.id },
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
      createdBy: systemUser.id,
      commissionTotal,
    });
  }

  const snapshot = await prisma.deal.findMany({
    include: {
      lead: { select: { id: true, title: true } },
      createdBy: { select: { id: true, email: true } },
      commissionEntries: true,
    },
  });

  console.log("==> DEALS SNAPSHOT");
  console.dir(snapshot, { depth: 5 });

  await prisma.$disconnect();
})();
NODE

echo ""
echo "🎯 DAY4–ADIM2 KESİN OLARAK TAMAMLANDI"
