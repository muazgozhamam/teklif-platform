#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$ROOT_DIR/apps/api"
BASE_URL="${BASE_URL:-http://localhost:3001}"

echo "==> 0) API ayakta mı?"
curl -sS "$BASE_URL/health" >/dev/null && echo "✅ health OK"

echo
echo "==> 1) apps/api env yükle (.env / .env.local varsa)"
cd "$API_DIR"
set +u
if [[ -f ".env" ]]; then
  export $(grep -v '^\s*#' .env | sed '/^\s*$/d' | xargs -0 2>/dev/null || true) || true
fi
if [[ -f ".env.local" ]]; then
  export $(grep -v '^\s*#' .env.local | sed '/^\s*$/d' | xargs -0 2>/dev/null || true) || true
fi
set -u

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "❌ DATABASE_URL env yok. apps/api/.env veya .env.local içinde olmalı."
  exit 2
fi

# tırnak/whitespace temizle
DATABASE_URL="$(node -p 'String(process.env.DATABASE_URL||"").trim().replace(/^["'"'"']|["'"'"']$/g,"")')"
export DATABASE_URL
echo "DATABASE_URL -> $DATABASE_URL"

echo
echo "==> 2) Prisma generate"
pnpm -s prisma generate --schema prisma/schema.prisma
echo "✅ prisma generate OK"

echo
echo "==> 3) CONSULTANT seed (Prisma.dmmf ile, driver adapter)"
node <<'NODE'
const crypto = require("crypto");

function norm(s){ return String(s||"").trim().replace(/^["']|["']$/g,""); }
function provider(url){
  const u = norm(url).toLowerCase();
  if (u.startsWith("postgres://") || u.startsWith("postgresql://")) return "postgres";
  if (u.startsWith("file:") || u.includes("sqlite")) return "sqlite";
  return "unknown";
}
function rid(){ return "seed_" + crypto.randomBytes(6).toString("hex"); }
function email(){ return `consultant_${Date.now()}_${Math.floor(Math.random()*1000)}@local.test`; }

function fillRequiredScalarsFromDmmf(model, PrismaNS){
  const data = {};
  for (const f of model.fields) {
    if (f.kind !== "scalar") continue;
    if (f.isList) continue;
    if (!f.isRequired) continue;
    if (f.hasDefaultValue) continue;

    if (f.type === "String") data[f.name] = (f.name.toLowerCase().includes("email") ? email() : rid());
    else if (f.type === "Int") data[f.name] = 0;
    else if (f.type === "BigInt") data[f.name] = BigInt(0);
    else if (f.type === "Boolean") data[f.name] = true;
    else if (f.type === "DateTime") data[f.name] = new Date();
    else if (f.type === "Json") data[f.name] = {};
    else if (f.type === "Bytes") data[f.name] = Buffer.from("seed");
    else {
      // enum olabilir
      const enumObj = PrismaNS && PrismaNS[f.type];
      if (enumObj && typeof enumObj === "object") {
        const vals = Object.values(enumObj);
        data[f.name] = vals[0];
      } else {
        data[f.name] = rid();
      }
    }
  }
  return data;
}

(async () => {
  const { PrismaClient, Prisma } = require("@prisma/client");

  const dbUrl = norm(process.env.DATABASE_URL);
  const p = provider(dbUrl);
  if (p !== "postgres") {
    console.error("❌ Bu script Postgres için yazıldı. Provider:", p, "URL:", dbUrl);
    process.exit(3);
  }

  const { Pool } = require("pg");
  const { PrismaPg } = require("@prisma/adapter-pg");
  const pool = new Pool({ connectionString: dbUrl });
  const adapter = new PrismaPg(pool);
  const prisma = new PrismaClient({ adapter });

  // DMMF’den User modeli bul
  const models = Prisma?.dmmf?.datamodel?.models || [];
  const userModel =
    models.find(m => m.name === "User") ||
    models.find(m => (m.name||"").toLowerCase() === "user");

  if (!userModel) {
    console.error("❌ Prisma.dmmf içinde User bulunamadı. Modeller:", models.map(m=>m.name).join(", "));
    process.exit(4);
  }

  const data = fillRequiredScalarsFromDmmf(userModel, Prisma);

  // yardımcı alanlar
  if (userModel.fields.some(f=>f.name==="name") && !data.name) data.name = "Seed Consultant";
  if (userModel.fields.some(f=>f.name==="email") && !data.email) data.email = email();

  // role alanı varsa CONSULTANT seçmeye çalış
  const roleField = userModel.fields.find(f => f.kind==="scalar" && (f.name==="role" || (f.name||"").toLowerCase().includes("role")));
  if (roleField) {
    const enumObj = Prisma[roleField.type];
    const vals = enumObj ? Object.values(enumObj) : [];
    const consultantVal =
      vals.find(v => String(v).toUpperCase() === "CONSULTANT") ||
      vals.find(v => String(v).toUpperCase() === "AGENT") ||
      vals[0];
    if (consultantVal) data[roleField.name] = consultantVal;
  }

  // olası aktif/uygunluk bayrakları
  for (const key of ["isActive","active","enabled","isEnabled","available","isAvailable"]) {
    if (userModel.fields.some(f=>f.name===key) && data[key] == null) data[key] = true;
  }

  // olası parola alanları (varsa zorunlu olabilir)
  for (const key of ["password","passwordHash","hash"]) {
    if (userModel.fields.some(f=>f.name===key) && !data[key]) data[key] = "seed";
  }

  const created = await prisma.user.create({ data });

  console.log("✅ Seed OK");
  console.log("CONSULTANT_ID=" + created.id);
  if (created.email) console.log("CONSULTANT_EMAIL=" + created.email);

  await prisma.$disconnect();
})().catch((e) => {
  console.error("SEED ERROR:", e?.message || e);
  process.exit(5);
});
NODE

echo
echo "==> 4) Yeni lead+deal üret ve match dene"
cd "$ROOT_DIR"
LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{ "initialText": "seed consultant then match" }')"
LEAD_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$LEAD_JSON")"
DEAL_JSON="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID")"
DEAL_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$DEAL_JSON")"
echo "LEAD_ID=$LEAD_ID"
echo "DEAL_ID=$DEAL_ID"

MATCH_RESP="$(curl -sS -X POST "$BASE_URL/deals/$DEAL_ID/match" || true)"
echo "Match response: $MATCH_RESP"

echo
echo "✅ DONE"
