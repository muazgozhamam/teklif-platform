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
echo "DATABASE_URL -> SET"

echo
echo "==> 2) Prisma generate"
pnpm -s prisma generate --schema prisma/schema.prisma
echo "✅ prisma generate OK"

echo
echo "==> 3) CONSULTANT seed (driver adapter ile)"
node <<'NODE'
const crypto = require("crypto");

function pickProvider(url) {
  const u = (url || "").toLowerCase();
  if (u.startsWith("postgres://") || u.startsWith("postgresql://")) return "postgres";
  if (u.startsWith("file:") || u.includes("sqlite")) return "sqlite";
  return "unknown";
}

function makeId() {
  return "seed_" + crypto.randomBytes(6).toString("hex");
}

function makeEmail() {
  return `consultant_${Date.now()}_${Math.floor(Math.random()*1000)}@local.test`;
}

function fillRequiredScalars(runtimeModel, PrismaNS) {
  const data = {};
  for (const f of runtimeModel.fields) {
    if (f.kind !== "scalar") continue;
    if (f.isList) continue;
    if (!f.isRequired) continue;
    if (f.hasDefaultValue) continue;

    if (f.type === "String") data[f.name] = (f.name.toLowerCase().includes("email") ? makeEmail() : makeId());
    else if (f.type === "Int") data[f.name] = 0;
    else if (f.type === "BigInt") data[f.name] = BigInt(0);
    else if (f.type === "Boolean") data[f.name] = true;
    else if (f.type === "DateTime") data[f.name] = new Date();
    else if (f.type === "Json") data[f.name] = {};
    else if (f.type === "Bytes") data[f.name] = Buffer.from("seed");
    else {
      const enumObj = PrismaNS && PrismaNS[f.type];
      if (enumObj && typeof enumObj === "object") {
        const vals = Object.values(enumObj);
        data[f.name] = vals[0];
      } else {
        data[f.name] = makeId();
      }
    }
  }
  return data;
}

(async () => {
  const { PrismaClient, Prisma } = require("@prisma/client");

  const dbUrl = process.env.DATABASE_URL;
  const provider = pickProvider(dbUrl);

  let prisma;

  if (provider === "postgres") {
    let Pool, PrismaPg;
    try {
      ({ Pool } = require("pg"));
      ({ PrismaPg } = require("@prisma/adapter-pg"));
    } catch (e) {
      console.error("❌ Postgres adapter eksik. Şunu çalıştır:");
      console.error("   cd apps/api && pnpm add -D pg @prisma/adapter-pg");
      process.exit(3);
    }
    const pool = new Pool({ connectionString: dbUrl });
    const adapter = new PrismaPg(pool);
    prisma = new PrismaClient({ adapter });
  } else if (provider === "sqlite") {
    let Database, PrismaSqlite;
    try {
      Database = require("better-sqlite3");
      ({ PrismaSqlite } = require("@prisma/adapter-sqlite"));
    } catch (e) {
      console.error("❌ SQLite adapter eksik. Şunu çalıştır:");
      console.error("   cd apps/api && pnpm add -D better-sqlite3 @prisma/adapter-sqlite");
      process.exit(3);
    }
    const filePath = dbUrl.startsWith("file:") ? dbUrl.replace(/^file:/, "") : dbUrl;
    const db = new Database(filePath);
    const adapter = new PrismaSqlite(db);
    prisma = new PrismaClient({ adapter });
  } else {
    console.error("❌ DATABASE_URL provider tanınmadı:", dbUrl);
    process.exit(3);
  }

  const userModel =
    prisma?._runtimeDataModel?.models?.find(m => m.name === "User") ||
    prisma?._runtimeDataModel?.models?.find(m => m.name.toLowerCase() === "user");

  if (!userModel) {
    console.error("❌ Prisma runtime model'de User bulunamadı.");
    console.error("   Modeller:", (prisma?._runtimeDataModel?.models || []).map(m=>m.name).join(", "));
    process.exit(4);
  }

  const roleField = userModel.fields.find(f => f.kind === "scalar" && (f.name === "role" || f.name.toLowerCase().includes("role")));
  const data = fillRequiredScalars(userModel, Prisma);

  if (!data.email && userModel.fields.some(f=>f.name==="email")) data.email = makeEmail();
  if (userModel.fields.some(f=>f.name==="name") && !data.name) data.name = "Seed Consultant";

  if (roleField) {
    const enumObj = Prisma[roleField.type];
    const vals = enumObj ? Object.values(enumObj) : [];
    const consultantVal =
      vals.find(v => String(v).toUpperCase() === "CONSULTANT") ||
      vals.find(v => String(v).toUpperCase() === "AGENT") ||
      vals[0];

    if (consultantVal) data[roleField.name] = consultantVal;
  }

  for (const key of ["isActive","active","enabled","isEnabled","available","isAvailable"]) {
    if (userModel.fields.some(f=>f.name===key) && data[key] == null) data[key] = true;
  }

  for (const key of ["password","passwordHash","hash"]) {
    if (userModel.fields.some(f=>f.name===key) && !data[key]) data[key] = "seed";
  }

  const email = data.email || makeEmail();

  let user;
  try {
    user = await prisma.user.create({ data: { ...data, email } });
  } catch (e) {
    const delegateName = Object.keys(prisma).find(k => prisma[k] && typeof prisma[k].create === "function" && k.toLowerCase() === "user");
    if (!delegateName) {
      console.error("❌ prisma.user delegate yok. Delegateler:", Object.keys(prisma).join(", "));
      throw e;
    }
    user = await prisma[delegateName].create({ data: { ...data, email } });
  }

  console.log("✅ Seed OK");
  console.log("CONSULTANT_ID=" + user.id);
  console.log("CONSULTANT_EMAIL=" + (user.email || email));

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
