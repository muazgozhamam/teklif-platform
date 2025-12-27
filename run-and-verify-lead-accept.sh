#!/usr/bin/env bash
set -e

LEAD_ID="80a5c36f-25c3-4fc8-99fc-812a98b1cf1f"
OFFER_ID="cmji05hst0000szgboozmf1dh"
PORT=3001

echo "==> 1) Killing anything on port $PORT"
lsof -ti :$PORT | xargs -r kill -9 || true
sleep 1

echo "==> 2) Verifying OffersService has lead update..."
FILE="apps/api/src/offers/offers.service.ts"
if ! grep -q "tx.lead.update" "$FILE"; then
  echo "❌ ERROR: tx.lead.update NOT FOUND in OffersService"
  echo "Fix uygulanmamış. Dosya bozuk."
  exit 1
fi
echo "✅ Lead update code exists."

echo "==> 3) Starting API (background)"
pnpm --filter api dev > /tmp/api.log 2>&1 &
API_PID=$!
sleep 4

if ! lsof -i :$PORT >/dev/null; then
  echo "❌ API did not bind to port $PORT"
  exit 1
fi
echo "✅ API running on port $PORT"

echo "==> 4) Triggering ACCEPTED again"
curl -s -X PATCH "http://localhost:$PORT/offers/status?customerId=customer_demo&offerId=$OFFER_ID" \
  -H "Content-Type: application/json" \
  -d '{"status":"ACCEPTED"}' >/dev/null

echo "==> 5) Reading Lead status via Prisma Client"
cd apps/api

node <<NODE
const { PrismaClient } = require("@prisma/client");
(async () => {
  const p = new PrismaClient();
  const lead = await p.lead.findUnique({
    where: { id: "$LEAD_ID" },
    select: { id: true, status: true, updatedAt: true }
  });
  console.log("==> LEAD RESULT:");
  console.log(lead);
  await p.\$disconnect();

  if (lead?.status === "ACTIVE") {
    console.log("🎯 SUCCESS: Lead is ACTIVE");
    process.exit(0);
  } else {
    console.error("❌ FAIL: Lead status is NOT ACTIVE");
    process.exit(2);
  }
})();
NODE
