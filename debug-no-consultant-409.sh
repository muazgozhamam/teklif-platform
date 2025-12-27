#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$ROOT_DIR/apps/api"
BASE_URL="${BASE_URL:-http://localhost:3001}"

DEAL_ID="${1:-}"

echo "==> 0) API health"
curl -sS "$BASE_URL/health" >/dev/null && echo "✅ health OK"
echo

echo "==> 1) Kodda 'No consultant available' nerede?"
cd "$ROOT_DIR"
if command -v rg >/dev/null 2>&1; then
  rg -n --hidden --no-ignore-vcs -S "No consultant available|ConflictException|match\(" apps/api/src || true
else
  grep -RIn "No consultant available" apps/api/src || true
fi
echo

echo "==> 2) DealId yoksa yeni lead+deal üret"
if [[ -z "$DEAL_ID" ]]; then
  LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{ "initialText": "debug 409 no consultant" }')"
  LEAD_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$LEAD_JSON")"
  DEAL_JSON="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID")"
  DEAL_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$DEAL_JSON")"
fi
echo "DEAL_ID=$DEAL_ID"
echo

echo "==> 3) apps/api env yükle (.env / .env.local varsa)"
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
  echo "❌ DATABASE_URL env yok."
  exit 2
fi
DATABASE_URL="$(node -p 'String(process.env.DATABASE_URL||"").trim().replace(/^["'"'"']|["'"'"']$/g,"")')"
export DATABASE_URL
echo "DATABASE_URL -> $DATABASE_URL"
echo

echo "==> 4) DB snapshot: Deal + User(consultant) adayları"
node <<NODE
const { Pool } = require("pg");
const { PrismaClient, Prisma } = require("@prisma/client");
const { PrismaPg } = require("@prisma/adapter-pg");

const DEAL_ID = ${JSON.stringify("$DEAL_ID")};

function norm(s){ return String(s||"").trim().replace(/^["']|["']$/g,""); }
function provider(url){
  const u = norm(url).toLowerCase();
  if (u.startsWith("postgres://") || u.startsWith("postgresql://")) return "postgres";
  return "unknown";
}

(async () => {
  const dbUrl = norm(process.env.DATABASE_URL);
  if (provider(dbUrl) !== "postgres") {
    console.error("Only postgres supported here. DATABASE_URL=", dbUrl);
    process.exit(3);
  }

  const pool = new Pool({ connectionString: dbUrl });
  const adapter = new PrismaPg(pool);
  const prisma = new PrismaClient({ adapter });

  // Deal'i getir
  const deal = await prisma.deal.findUnique({
    where: { id: DEAL_ID },
    include: { lead: true, consultant: true },
  });

  console.log("---- DEAL ----");
  console.log(JSON.stringify(deal, null, 2));

  // User model field listesi (match filtrelerini tahmin etmek için)
  const userModel = (Prisma?.dmmf?.datamodel?.models || []).find(m => m.name === "User");
  console.log("\\n---- USER MODEL FIELDS (DMMF) ----");
  console.log(userModel ? userModel.fields.map(f => ({
    name: f.name, kind: f.kind, type: f.type, required: f.isRequired, list: f.isList, hasDefault: f.hasDefaultValue
  })) : "User model not found");

  // Muhtemel filtre alanları: role/active/available/city/district/status vb.
  const candidates = await prisma.user.findMany({
    take: 50,
    orderBy: { createdAt: "desc" },
  });

  console.log("\\n---- LAST 50 USERS (RAW) ----");
  console.log(JSON.stringify(candidates, null, 2));

  // Role bazlı sayım (varsa)
  const roles = {};
  for (const u of candidates) {
    const r = (u.role ?? "NO_ROLE");
    roles[r] = (roles[r] || 0) + 1;
  }
  console.log("\\n---- ROLE COUNTS (last 50) ----");
  console.log(roles);

  await prisma.\$disconnect();
  await pool.end();
})().catch((e) => {
  console.error("SNAPSHOT ERROR:", e?.message || e);
  process.exit(5);
});
NODE

echo
echo "==> 5) Match endpoint tekrar dene (çıktıyı gör)"
curl -sS -X POST "$BASE_URL/deals/$DEAL_ID/match" || true
echo
echo "✅ DONE (debug)"
