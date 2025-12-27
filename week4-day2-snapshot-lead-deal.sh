#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
API_DIR="$ROOT/apps/api"

if [ ! -d "$API_DIR" ]; then
  echo "ERROR: apps/api bulunamadı: $API_DIR"
  exit 1
fi

OFFER_ID="${1:-}"
LEAD_ID="${2:-}"

if [ -z "${OFFER_ID}" ] && [ -z "${LEAD_ID}" ]; then
  echo "KULLANIM:"
  echo "  ./week4-day2-snapshot-lead-deal.sh <offerId>"
  echo "  ./week4-day2-snapshot-lead-deal.sh <offerId> <leadId>"
  echo "  ./week4-day2-snapshot-lead-deal.sh '' <leadId>"
  exit 1
fi

cd "$API_DIR"

node - "$OFFER_ID" "$LEAD_ID" <<'NODE'
const { PrismaClient } = require("@prisma/client");

const offerId = process.argv[2] || "";
const leadIdArg = process.argv[3] || "";

(async () => {
  const p = new PrismaClient();
  const sep = () => console.log("\n" + "-".repeat(80) + "\n");

  let offer = null;
  if (offerId && offerId !== "''") {
    offer = await p.offer.findUnique({ where: { id: offerId } });
    console.log("==> OFFER");
    console.dir(offer, { depth: 5 });
    sep();
  }

  const leadId = (leadIdArg && leadIdArg !== "''") ? leadIdArg : (offer?.requestId || "");
  if (!leadId) {
    console.log("ERROR: leadId belirlenemedi. offerId yanlış olabilir veya leadId vermedin.");
    await p.$disconnect();
    process.exit(1);
  }

  const lead = await p.lead.findUnique({
    where: { id: leadId },
    include: { deal: true },
  });

  console.log("==> LEAD");
  console.dir(lead, { depth: 6 });
  sep();

  const offers = await p.offer.findMany({
    where: { requestId: leadId },
    orderBy: { createdAt: "desc" },
  });

  console.log("==> OFFERS for LEAD (requestId =", leadId + ")");
  console.table(offers.map(o => ({
    id: o.id,
    providerId: o.providerId,
    price: o.price,
    status: o.status,
    createdAt: o.createdAt?.toISOString?.() || o.createdAt,
    updatedAt: o.updatedAt?.toISOString?.() || o.updatedAt,
  })));
  sep();

  const deal = await p.deal.findFirst({
    where: { leadId },
    include: { ledgerEntries: true, lead: true, createdBy: true },
    orderBy: { createdAt: "desc" },
  });

  console.log("==> DEAL (by leadId)");
  console.dir(deal, { depth: 7 });
  sep();

  if (deal?.ledgerEntries?.length) {
    console.log("==> LEDGER ENTRIES (CommissionEntry)");
    console.table(deal.ledgerEntries.map(e => ({
      id: e.id,
      beneficiaryRole: e.beneficiaryRole,
      percent: e.percent,
      amount: e.amount,
      createdAt: e.createdAt?.toISOString?.() || e.createdAt,
    })));
    sep();
  } else {
    console.log("==> LEDGER ENTRIES: yok");
    sep();
  }

  console.log("✅ SNAPSHOT DONE");
  await p.$disconnect();
})().catch(async (e) => {
  console.error("SNAPSHOT ERROR:", e);
  process.exit(1);
});
NODE
