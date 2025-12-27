#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
API_DIR="$ROOT_DIR/apps/api"
BASE_URL="${BASE_URL:-http://localhost:3001}"

echo "==> 0) API health"
curl -sS "$BASE_URL/health" >/dev/null && echo "✅ health OK"
echo

echo "==> 1) apps/api env yükle (.env / .env.local varsa)"
cd "$API_DIR"
set +u
for f in ".env" ".env.local" "$ROOT_DIR/.env" "$ROOT_DIR/.env.local"; do
  if [[ -f "$f" ]]; then
    export $(grep -v '^\s*#' "$f" | sed '/^\s*$/d' | xargs 2>/dev/null || true) || true
  fi
done
set -u

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "❌ DATABASE_URL env yok."
  exit 2
fi

DATABASE_URL="$(node -p 'String(process.env.DATABASE_URL||"").trim().replace(/^["'"'"']|["'"'"']$/g,"")')"
export DATABASE_URL
echo "DATABASE_URL -> $DATABASE_URL"
echo

echo "==> 2) Prisma generate"
pnpm -s prisma generate --schema prisma/schema.prisma
echo "✅ prisma generate OK"
echo

echo "==> 3) Consultant seed / role fix (DB direct, adapter-pg)"
node <<'NODE'
const { Pool } = require("pg");
const { PrismaClient } = require("@prisma/client");
const { PrismaPg } = require("@prisma/adapter-pg");

function norm(s){ return String(s||"").trim().replace(/^["']|["']$/g,""); }

(async () => {
  const dbUrl = norm(process.env.DATABASE_URL);
  if (!dbUrl) throw new Error("DATABASE_URL empty");
  if (!(dbUrl.startsWith("postgres://") || dbUrl.startsWith("postgresql://"))) {
    throw new Error("DATABASE_URL postgres değil: " + dbUrl);
  }

  const pool = new Pool({ connectionString: dbUrl });
  const adapter = new PrismaPg(pool);
  const prisma = new PrismaClient({ adapter });

  const email = "consultant@local.test";

  // varsa role'ü düzelt, yoksa oluştur
  const existing = await prisma.user.findUnique({ where: { email } }).catch(() => null);

  let user;
  if (existing) {
    user = await prisma.user.update({
      where: { email },
      data: { role: "CONSULTANT", name: existing.name ?? "Local Consultant" },
    });
    console.log("✅ UPDATED consultant role -> CONSULTANT");
  } else {
    user = await prisma.user.create({
      data: {
        email,
        password: "seed", // sadece local seed
        name: "Local Consultant",
        role: "CONSULTANT",
      },
    });
    console.log("✅ CREATED consultant (CONSULTANT)");
  }

  console.log("CONSULTANT_ID=" + user.id);
  console.log("CONSULTANT_EMAIL=" + user.email);
  console.log("CONSULTANT_ROLE=" + user.role);

  // hızlı kontrol: kaç consultant var?
  const count = await prisma.user.count({ where: { role: "CONSULTANT" } });
  console.log("CONSULTANT_COUNT=" + count);

  await prisma.$disconnect();
  await pool.end();
})().catch((e) => {
  console.error("SEED ERROR:", e?.message || e);
  process.exit(3);
});
NODE
echo

echo "==> 4) Yeni lead + deal üret"
cd "$ROOT_DIR"
LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{ "initialText": "fix consultant role then match" }')"
LEAD_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$LEAD_JSON")"
DEAL_JSON="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID")"
DEAL_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$DEAL_JSON")"
echo "LEAD_ID=$LEAD_ID"
echo "DEAL_ID=$DEAL_ID"
echo

echo "==> 5) Match dene"
MATCH_RESP="$(curl -sS -X POST "$BASE_URL/deals/$DEAL_ID/match" || true)"
echo "Match response: $MATCH_RESP"
echo

echo "==> 6) Deal'i tekrar çek (ASSIGNED mı?)"
curl -sS "$BASE_URL/deals/$DEAL_ID" || true
echo
echo "✅ DONE"
