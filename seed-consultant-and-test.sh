#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
API_DIR="$ROOT_DIR/apps/api"
SEED_DIR="$API_DIR/prisma/seed"
SEED_FILE="$SEED_DIR/consultant.seed.js"

BASE_URL="${BASE_URL:-http://localhost:3001}"

echo "==> 0) Root: $ROOT_DIR"
echo "==> 0) API : $API_DIR"
echo

mkdir -p "$SEED_DIR"

# Mevcut seed dosyasını ezmeden yedekle
if [[ -f "$SEED_FILE" ]]; then
  TS="$(date +%Y%m%d-%H%M%S)"
  cp "$SEED_FILE" "$SEED_FILE.bak.$TS"
  echo "==> 1) Seed dosyası vardı, yedek alındı: $SEED_FILE.bak.$TS"
else
  echo "==> 1) Seed dosyası yok, oluşturulacak."
fi

cat > "$SEED_FILE" <<'NODE'
/**
 * consultant.seed.js
 * - Driver adapter (pg + @prisma/adapter-pg) ile PrismaClient açar (engineType=client gereği).
 * - DB'de consultant@local.test varsa role'ünü CONSULTANT yapar, yoksa oluşturur.
 *
 * Çalıştırma: node prisma/seed/consultant.seed.js
 */
const { Pool } = require("pg");
const { PrismaClient } = require("@prisma/client");
const { PrismaPg } = require("@prisma/adapter-pg");

function norm(s){ return String(s || "").trim().replace(/^["']|["']$/g, ""); }

(async () => {
  const dbUrl = norm(process.env.DATABASE_URL);
  if (!dbUrl) {
    console.error("❌ DATABASE_URL yok. apps/api/.env veya ortam değişkeni olmalı.");
    process.exit(2);
  }
  const lower = dbUrl.toLowerCase();
  if (!(lower.startsWith("postgres://") || lower.startsWith("postgresql://"))) {
    console.error("❌ DATABASE_URL postgres değil:", dbUrl);
    process.exit(3);
  }

  const pool = new Pool({ connectionString: dbUrl });
  const adapter = new PrismaPg(pool);
  const prisma = new PrismaClient({ adapter });

  const email = "consultant@local.test";
  const password = "seed"; // prod değil; local seed için.
  const name = "Local Consultant";

  const existing = await prisma.user.findUnique({ where: { email } });

  if (existing) {
    const updated = await prisma.user.update({
      where: { email },
      data: { role: "CONSULTANT", name: existing.name ?? name },
    });
    console.log("✅ Consultant vardı -> role güncellendi:", {
      id: updated.id, email: updated.email, role: updated.role
    });
  } else {
    const created = await prisma.user.create({
      data: { email, password, name, role: "CONSULTANT" },
    });
    console.log("✅ Consultant oluşturuldu:", {
      id: created.id, email: created.email, role: created.role
    });
  }

  const count = await prisma.user.count({ where: { role: "CONSULTANT" } });
  console.log("CONSULTANT_COUNT=", count);

  await prisma.$disconnect();
  await pool.end();
})().catch((e) => {
  console.error("❌ SEED ERROR:", e?.message || e);
  process.exit(5);
});
NODE

echo "==> 2) Seed dosyası yazıldı: $SEED_FILE"
echo

echo "==> 3) apps/api env yükle (.env / .env.local varsa)"
set +u
if [[ -f "$API_DIR/.env" ]]; then
  set -a; source "$API_DIR/.env"; set +a
fi
if [[ -f "$API_DIR/.env.local" ]]; then
  set -a; source "$API_DIR/.env.local"; set +a
fi
set -u

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "❌ DATABASE_URL bulunamadı. apps/api/.env içine koymalısın."
  exit 10
fi
echo "DATABASE_URL -> ${DATABASE_URL}"
echo

echo "==> 4) Prisma generate"
pushd "$API_DIR" >/dev/null
pnpm -s prisma generate --schema prisma/schema.prisma
popd >/dev/null
echo "✅ prisma generate OK"
echo

echo "==> 5) Seed çalıştır"
pushd "$API_DIR" >/dev/null
node "prisma/seed/consultant.seed.js"
popd >/dev/null
echo

echo "==> 6) E2E lead->deal->match test"
# API ayakta olmalı (pnpm start:dev çalışıyor olmalı)
curl -sS "$BASE_URL/health" >/dev/null || {
  echo "❌ API'ye erişemiyorum: $BASE_URL/health"
  echo "Önce şu komutla API'yi çalıştır:"
  echo "  cd apps/api && pnpm start:dev"
  exit 20
}

LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{ "initialText": "seed consultant then match (script)" }')"
LEAD_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$LEAD_JSON")"

DEAL_JSON="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID")"
DEAL_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$DEAL_JSON")"

echo "LEAD_ID=$LEAD_ID"
echo "DEAL_ID=$DEAL_ID"
echo

MATCH_RESP="$(curl -sS -X POST "$BASE_URL/deals/$DEAL_ID/match" || true)"
echo "Match response: $MATCH_RESP"
echo

echo "==> 7) Deal'i çek (ASSIGNED doğrula)"
curl -sS "$BASE_URL/deals/$DEAL_ID" || true
echo
echo "✅ DONE"
