#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
DEAL_ID="${1:-}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Eksik komut: $1"; exit 1; }; }
need curl
need node

echo "==> 0) DealId yoksa, yeni lead+deal üret"
if [[ -z "${DEAL_ID}" ]]; then
  LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{ "initialText": "seed consultant + match retry v2" }')"
  LEAD_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$LEAD_JSON")"
  DEAL_JSON="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID")"
  DEAL_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$DEAL_JSON")"
fi
echo "DEAL_ID=$DEAL_ID"
echo

echo "==> 1) apps/api ENV yükle (varsa .env, .env.local)"
pushd apps/api >/dev/null

set -a
[[ -f .env ]] && source .env
[[ -f .env.local ]] && source .env.local
[[ -f .env.development ]] && source .env.development
set +a

echo "DATABASE_URL set mi? -> ${DATABASE_URL:+YES}"
echo "PRISMA_ACCELERATE_URL set mi? -> ${PRISMA_ACCELERATE_URL:+YES}"
echo

echo "==> 2) Prisma ile consultant seed"
node <<'NODE'
const { PrismaClient } = require("@prisma/client");

function buildOptions() {
  const opts = {};
  if (process.env.DATABASE_URL) {
    opts.datasources = { db: { url: process.env.DATABASE_URL } };
  }
  // Bazı projelerde accelerate aktif olabilir
  if (process.env.PRISMA_ACCELERATE_URL) {
    opts.accelerateUrl = process.env.PRISMA_ACCELERATE_URL;
  }
  // opts boşsa bile oluşturmayı deneyeceğiz; hata verirse çıktıyı göreceğiz.
  return opts;
}

(async () => {
  const opts = buildOptions();
  const prisma = new PrismaClient(opts);

  const email = "consultant1@test.local";

  let existing = await prisma.user.findFirst({ where: { email } }).catch(() => null);
  if (existing) {
    console.log("EXISTING CONSULTANT:", existing.id);
    await prisma.$disconnect();
    return;
  }

  // Minimal alanlar — şema farklıysa hata mesajından alan ekleyerek ilerleriz
  const data = { email, name: "Consultant One", role: "CONSULTANT" };

  try {
    const created = await prisma.user.create({ data });
    console.log("CREATED CONSULTANT:", created.id);
  } finally {
    await prisma.$disconnect();
  }
})().catch((e) => {
  console.error("SEED ERROR:", e?.message || e);
  process.exit(2);
});
NODE

popd >/dev/null
echo

echo "==> 3) Match tekrar dene"
curl -sS -X POST "$BASE_URL/deals/$DEAL_ID/match"
echo
echo "✅ DONE"
