#!/usr/bin/env bash
set -e

API_DIR="apps/api"
SERVICE="$API_DIR/src/offers/offers.service.ts"
PORT=3001

echo "==> 1) Ensuring Deal creation logic in OffersService"

# Deal create yoksa ekle
if ! grep -q "tx\.deal\.create" "$SERVICE"; then
  perl -0777 -i -pe '
    s/(await\s+tx\.lead\.update\([\s\S]*?\);\s*)/$1\n        // Create Deal (only once per Lead)\n        const existingDeal = await tx.deal.findUnique({ where: { leadId: offer.requestId } });\n        if (!existingDeal) {\n          const deal = await tx.deal.create({\n            data: {\n              leadId: offer.requestId,\n              offerId: offer.id,\n              price: offer.price,\n              commissionRate: 0.02,\n            },\n          });\n\n          // Create Commission Entry (percent-based)\n          await tx.commissionEntry.create({\n            data: {\n              dealId: deal.id,\n              amount: offer.price * 0.02,\n              description: \"Broker commission (%2)\",\n            },\n          });\n        }\n/s
  ' "$SERVICE"
  echo "✅ Deal + Commission logic injected."
else
  echo "ℹ️ Deal logic already exists, skipping injection."
fi

echo "==> 2) Restarting API cleanly"
lsof -ti :$PORT | xargs -r kill -9 || true
sleep 1
pnpm --filter api dev > /tmp/api.log 2>&1 &
sleep 4

echo "==> 3) Backfilling Deal for existing ACCEPTED offers"

cd "$API_DIR"

node <<'NODE'
const { PrismaClient } = require("@prisma/client");
(async () => {
  const p = new PrismaClient();

  const offers = await p.offer.findMany({
    where: { status: "ACCEPTED" },
    include: { deal: true },
  });

  for (const o of offers) {
    const existing = await p.deal.findUnique({ where: { leadId: o.requestId } });
    if (existing) continue;

    const deal = await p.deal.create({
      data: {
        leadId: o.requestId,
        offerId: o.id,
        price: o.price,
        commissionRate: 0.02,
      },
    });

    await p.commissionEntry.create({
      data: {
        dealId: deal.id,
        amount: o.price * 0.02,
        description: "Broker commission (%2)",
      },
    });

    console.log("✔ Deal created for lead:", o.requestId);
  }

  const deals = await p.deal.findMany({
    include: { commissionEntries: true },
  });

  console.log("==> DEALS SNAPSHOT");
  console.dir(deals, { depth: 4 });

  await p.$disconnect();
})();
NODE

echo ""
echo "🎯 Day4–Adım2 COMPLETED"
echo "Deal + CommissionEntry hazır."
