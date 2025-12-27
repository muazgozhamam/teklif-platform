#!/usr/bin/env bash
set -euo pipefail

API_DIR="apps/api"

if [ ! -d "$API_DIR" ]; then
  echo "ERROR: $API_DIR yok."
  exit 1
fi

OFFER_ID="${1:-}"
if [ -z "$OFFER_ID" ]; then
  echo "KULLANIM: ./week4-day2-create-deal-from-accepted-offer.sh <OFFER_ID>"
  exit 1
fi

cd "$API_DIR"

OFFER_ID="$OFFER_ID" node <<'NODE'
const offerId = process.env.OFFER_ID;
const commissionRateDefault = 0.02; // %2
const dealStatusDefault = "ACTIVE";
const beneficiaryRoleDefault = "BROKER"; // MVP: komisyonun hak sahibi

const { PrismaClient, Prisma } = require("@prisma/client");
const p = new PrismaClient();

function getModel(name) {
  const models = Prisma?.dmmf?.datamodel?.models || [];
  return models.find(m => m.name === name);
}
function fieldNames(model) {
  return new Set((model?.fields || []).map(f => f.name));
}

(async () => {
  const OfferM = getModel("Offer");
  const LeadM  = getModel("Lead");
  const DealM  = getModel("Deal");
  const CE     = getModel("CommissionEntry");

  if (!OfferM || !LeadM || !DealM || !CE) {
    console.log("ERROR: DMMF model bulunamadı.");
    console.log("Offer:", !!OfferM, "Lead:", !!LeadM, "Deal:", !!DealM, "CommissionEntry:", !!CE);
    process.exit(1);
  }

  const ceFields = fieldNames(CE);

  // 1) Offer bul
  const offer = await p.offer.findUnique({
    where: { id: offerId },
    select: { id: true, status: true, requestId: true, providerId: true, price: true }
  });
  if (!offer) {
    console.log("ERROR: Offer bulunamadı:", offerId);
    return;
  }
  if (offer.status !== "ACCEPTED") {
    console.log("ERROR: Offer ACCEPTED değil. Şu an:", offer.status);
    return;
  }

  // 2) Lead bul
  const lead = await p.lead.findUnique({
    where: { id: offer.requestId },
    select: { id: true, status: true, createdById: true }
  });
  if (!lead) {
    console.log("ERROR: Lead bulunamadı. Offer.requestId:", offer.requestId);
    return;
  }

  // 3) Deal var mı?
  const existingDeal = await p.deal.findFirst({
    where: { leadId: lead.id },
    select: { id: true }
  });
  if (existingDeal) {
    console.log("OK: Bu lead için Deal zaten var:", existingDeal.id);
    return;
  }

  // 4) Deal hesapları
  const salePrice = Number(offer.price);
  const commissionRate = commissionRateDefault;
  const commissionTotal = Number((salePrice * commissionRate).toFixed(2));

  // 5) CommissionEntry create payload (schema-aware)
  const ceData = {};

  // Zorunlu alanlar (sende çıktı: beneficiaryRole, percent)
  if (ceFields.has("beneficiaryRole")) ceData.beneficiaryRole = beneficiaryRoleDefault;
  if (ceFields.has("percent")) ceData.percent = commissionRate;

  // Amount alanı (farklı isim olasılıkları)
  if (ceFields.has("amount")) ceData.amount = commissionTotal;
  else if (ceFields.has("commissionAmount")) ceData.commissionAmount = commissionTotal;
  else if (ceFields.has("total")) ceData.total = commissionTotal;
  else if (ceFields.has("value")) ceData.value = commissionTotal;

  // createdBy varsa
  if (ceFields.has("createdById")) ceData.createdById = lead.createdById;

  // Note/description alanı varsa
  const note = `Auto ledger: offer=${offer.id} accepted; provider=${offer.providerId}`;
  if (ceFields.has("description")) ceData.description = note;
  else if (ceFields.has("note")) ceData.note = note;
  else if (ceFields.has("memo")) ceData.memo = note;

  // Optional type/kind/status alanları
  if (ceFields.has("type")) ceData.type = "COMMISSION";
  if (ceFields.has("kind")) ceData.kind = "COMMISSION";
  if (ceFields.has("status")) ceData.status = "POSTED";

  // required scalar check
  const requiredScalar = (CE.fields || []).filter(f =>
    f.kind === "scalar" &&
    f.isRequired &&
    !["id", "dealId", "createdAt", "updatedAt"].includes(f.name)
  );
  const missing = requiredScalar.filter(f => ceData[f.name] === undefined);
  if (missing.length) {
    console.log("ERROR: CommissionEntry zorunlu alan(lar)ı hala doldurulamadı:");
    console.log(missing.map(m => `${m.name}:${m.type}`).join(", "));
    return;
  }

  // 6) Deal create
  const created = await p.deal.create({
    data: {
      lead: { connect: { id: lead.id } },
      createdBy: { connect: { id: lead.createdById } },
      salePrice,
      commissionRate,
      commissionTotal,
      status: dealStatusDefault,
      ledgerEntries: { create: [ceData] },
    },
    include: { ledgerEntries: true }
  });

  console.log("✅ Deal created:", {
    id: created.id,
    leadId: created.leadId,
    salePrice: created.salePrice,
    commissionRate: created.commissionRate,
    commissionTotal: created.commissionTotal,
    ledgerCount: created.ledgerEntries.length
  });

})().catch(e => {
  console.error("FATAL:", e);
  process.exit(1);
}).finally(async () => {
  await p.$disconnect();
});
NODE
