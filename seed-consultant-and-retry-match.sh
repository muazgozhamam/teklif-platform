#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
DEAL_ID="${1:-}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Eksik komut: $1"; exit 1; }; }
need curl
need node

echo "==> 0) DealId yoksa, yeni lead+deal üretip onun dealId'sini kullan"
if [[ -z "${DEAL_ID}" ]]; then
  LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{ "initialText": "seed consultant + match retry" }')"
  LEAD_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$LEAD_JSON")"
  DEAL_JSON="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID")"
  DEAL_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$DEAL_JSON")"
fi

echo "DEAL_ID=$DEAL_ID"
echo

echo "==> 1) Consultant seed (Prisma) - apps/api içinde çalıştırıyoruz"
pushd apps/api >/dev/null

node <<'NODE'
const { PrismaClient } = require("@prisma/client");

function guessValue(field) {
  const f = field.toLowerCase();
  if (f.includes("email")) return "consultant1@test.local";
  if (f.includes("name")) return "Consultant One";
  if (f.includes("phone") || f.includes("gsm") || f.includes("tel")) return "5000000000";
  if (f.includes("password")) return "dummy_hash";
  if (f.includes("hash")) return "dummy_hash";
  if (f.includes("role")) return "CONSULTANT";
  if (f.includes("status")) return "ACTIVE";
  if (f.includes("active")) return true;
  if (f.includes("enabled")) return true;
  if (f.includes("verified")) return true;
  if (f.includes("city")) return "KONYA";
  if (f.includes("district")) return "MERAM";
  // default fallback
  return "dummy";
}

(async () => {
  const prisma = new PrismaClient();

  // 1) önce zaten consultant var mı bak
  // role alanı enum olmayabilir; bu yüzden hata olursa role filtresi olmadan first alacağız.
  let existing = null;
  try {
    existing = await prisma.user.findFirst({ where: { email: "consultant1@test.local" } });
  } catch (_) {}

  if (existing) {
    console.log("EXISTING CONSULTANT:", existing.id);
    await prisma.$disconnect();
    return;
  }

  // 2) adaptif create: zorunlu alan çıkarsa otomatik doldurup retry
  let data = {
    email: "consultant1@test.local",
    name: "Consultant One",
    role: "CONSULTANT",
  };

  const maxTries = 12;
  for (let i = 1; i <= maxTries; i++) {
    try {
      const created = await prisma.user.create({ data });
      console.log("CREATED CONSULTANT:", created.id);
      await prisma.$disconnect();
      return;
    } catch (e) {
      const msg = String(e?.message || e);

      // "Argument `xxx` is missing." / "Missing a required value at `xxx`" varyasyonları
      let m =
        msg.match(/Argument\s+`([^`]+)`\s+is missing/i) ||
        msg.match(/Missing a required value at `([^`]+)`/i) ||
        msg.match(/Required.*?`([^`]+)`/i);

      if (m && m[1]) {
        const field = m[1].split(".").pop(); // nested ise son parça
        if (!(field in data)) {
          data[field] = guessValue(field);
          console.log(`RETRY ${i}: missing '${field}', setting ->`, data[field]);
          continue;
        }
      }

      // Unknown arg ise alanı çıkarıp tekrar dene
      const u = msg.match(/Unknown arg `([^`]+)`/i);
      if (u && u[1]) {
        const field = u[1];
        if (field in data) {
          delete data[field];
          console.log(`RETRY ${i}: unknown '${field}', removing`);
          continue;
        }
      }

      console.error("SEED FAILED (unhandled):", msg);
      process.exit(2);
    }
  }

  console.error("SEED FAILED: max retry reached");
  process.exit(2);
})();
NODE

popd >/dev/null
echo

echo "==> 2) Match tekrar dene"
curl -sS -X POST "$BASE_URL/deals/$DEAL_ID/match"
echo
echo "✅ DONE"
