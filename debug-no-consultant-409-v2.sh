#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$ROOT_DIR/apps/api"
BASE_URL="${BASE_URL:-http://localhost:3001}"

DEAL_ID="${1:-}"

echo "==> 0) API health"
curl -sS "$BASE_URL/health" >/dev/null && echo "✅ health OK"
echo

echo "==> 1) No consultant available - aktif dosyada nerede? (deals.service.ts)"
cd "$ROOT_DIR"
FILE="$ROOT_DIR/apps/api/src/deals/deals.service.ts"
if [[ ! -f "$FILE" ]]; then
  echo "❌ Bulunamadı: $FILE"
  exit 2
fi

LINE="$(rg -n "No consultant available" "$FILE" | head -n1 | cut -d: -f1 || true)"
echo "FILE=$FILE"
echo "LINE=$LINE"
echo

if [[ -n "$LINE" ]]; then
  echo "---- CONTEXT (LINE-80 .. LINE+30) ----"
  START=$(( LINE-80 )); if [[ $START -lt 1 ]]; then START=1; fi
  END=$(( LINE+30 ))
  nl -ba "$FILE" | sed -n "${START},${END}p"
  echo "---- /CONTEXT ----"
else
  echo "⚠️ Bu dosyada metin bulunamadı (başka .bak dosyalarda olabilir)."
fi
echo

echo "==> 2) DealId yoksa yeni lead+deal üret"
if [[ -z "$DEAL_ID" ]]; then
  LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{ "initialText": "debug 409 no consultant v2" }')"
  LEAD_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$LEAD_JSON")"
  DEAL_JSON="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID")"
  DEAL_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$DEAL_JSON")"
fi
echo "DEAL_ID=$DEAL_ID"
echo

echo "==> 3) apps/api env yükle (.env / .env.local varsa) + DATABASE_URL normalize"
cd "$API_DIR"
set +u
for f in ".env" ".env.local" "$ROOT_DIR/.env" "$ROOT_DIR/.env.local"; do
  if [[ -f "$f" ]]; then
    # basit env load (space/quote karmaşası yoksa yeterli)
    export $(grep -v '^\s*#' "$f" | sed '/^\s*$/d' | xargs 2>/dev/null || true) || true
  fi
done
set -u

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "❌ DATABASE_URL env yok."
  exit 3
fi
DATABASE_URL="$(node -p 'String(process.env.DATABASE_URL||"").trim().replace(/^["'"'"']|["'"'"']$/g,"")')"
export DATABASE_URL
echo "DATABASE_URL -> $DATABASE_URL"
echo

echo "==> 4) DB snapshot: Deal + son kullanıcılar"
export DEAL_ID

node <<'NODE'
const { Pool } = require("pg");
const { PrismaClient, Prisma } = require("@prisma/client");
const { PrismaPg } = require("@prisma/adapter-pg");

function norm(s){ return String(s||"").trim().replace(/^["']|["']$/g,""); }

(async () => {
  const dealId = norm(process.env.DEAL_ID);
  const dbUrl = norm(process.env.DATABASE_URL);

  if (!dealId) throw new Error("DEAL_ID env empty");
  if (!dbUrl) throw new Error("DATABASE_URL env empty");
  if (!(dbUrl.startsWith("postgres://") || dbUrl.startsWith("postgresql://"))) {
    throw new Error(`DATABASE_URL postgres değil: ${dbUrl}`);
  }

  const pool = new Pool({ connectionString: dbUrl });
  const adapter = new PrismaPg(pool);
  const prisma = new PrismaClient({ adapter });

  const deal = await prisma.deal.findUnique({
    where: { id: dealId },
    include: { lead: true, consultant: true },
  });

  console.log("---- DEAL ----");
  console.log(JSON.stringify(deal, null, 2));

  const userModel = (Prisma?.dmmf?.datamodel?.models || []).find(m => m.name === "User");
  console.log("\n---- USER MODEL FIELDS (DMMF) ----");
  console.log(userModel ? userModel.fields.map(f => ({
    name: f.name, kind: f.kind, type: f.type, required: f.isRequired, list: f.isList, hasDefault: f.hasDefaultValue
  })) : "User model not found");

  const users = await prisma.user.findMany({
    take: 50,
    orderBy: { createdAt: "desc" },
  });

  console.log("\n---- LAST 50 USERS (RAW) ----");
  console.log(JSON.stringify(users, null, 2));

  const roles = {};
  for (const u of users) roles[String(u.role ?? "NO_ROLE")] = (roles[String(u.role ?? "NO_ROLE")] || 0) + 1;
  console.log("\n---- ROLE COUNTS (last 50) ----");
  console.log(roles);

  await prisma.$disconnect();
  await pool.end();
})().catch((e) => {
  console.error("SNAPSHOT ERROR:", e?.message || e);
  process.exit(5);
});
NODE

echo
echo "==> 5) Match endpoint tekrar dene (aynı deal)"
curl -sS -X POST "$BASE_URL/deals/$DEAL_ID/match" || true
echo
echo "✅ DONE (debug v2)"
