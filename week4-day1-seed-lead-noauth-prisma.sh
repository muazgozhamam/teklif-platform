#!/usr/bin/env bash
set -euo pipefail

API_DIR="apps/api"

cd "$API_DIR"

echo "==> Seeding Lead via Prisma Client (no auth)..."

node <<'NODE'
const { PrismaClient } = require("@prisma/client");

(async () => {
  const prisma = new PrismaClient();
  try {
    const user = await prisma.user.findFirst({
      orderBy: { createdAt: "desc" },
      select: { id: true, email: true, createdAt: true },
    });

    if (!user) {
      console.error("ERROR: User tablosunda hiç kayıt yok. Önce /auth/register ile kullanıcı oluştur.");
      process.exit(1);
    }

    const lead = await prisma.lead.create({
      data: {
        createdById: user.id,
        category: "KONUT",
        status: "PENDING_BROKER_APPROVAL",
        title: "Test Lead 1",
        city: "Konya",
        district: "Meram",
        notes: "Week4-Day1 noauth seed (prisma)",
        // submittedAt default zaten var ama açık yazmak sorun değil
        submittedAt: new Date(),
      },
      select: { id: true, status: true, title: true, createdById: true, createdAt: true },
    });

    console.log("==> Using user:", user);
    console.log("==> Created lead:", lead);
  } finally {
    await prisma.$disconnect();
  }
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
NODE
