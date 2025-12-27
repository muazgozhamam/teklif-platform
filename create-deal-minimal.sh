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
    },
  });

  await prisma.commissionEntry.create({
    data: {
      dealId: deal.id,
      amount: offer.price * 0.02,
      description: "Broker commission %2",
    },
  });

  console.log("✔ DEAL OLUŞTU:", deal.id);

  await prisma.$disconnect();
})();
NODE

./node_modules/.bin/echo "DONE"
