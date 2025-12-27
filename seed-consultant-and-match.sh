#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
API_DIR="apps/api"

echo "==> 0) API ayakta mı?"
curl -fsS "$BASE_URL/health" >/dev/null && echo "✅ health OK" || { echo "❌ API yok: $BASE_URL"; exit 1; }
echo

echo "==> 1) apps/api env yükle (.env / .env.local varsa)"
cd "$API_DIR"
if [[ -f .env ]]; then
  set -a; . ./.env; set +a
fi
if [[ -f .env.local ]]; then
  set -a; . ./.env.local; set +a
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "❌ DATABASE_URL set değil. apps/api/.env veya .env.local içinde olmalı."
  exit 2
fi

echo "DATABASE_URL -> SET"
echo

echo "==> 2) Prisma generate (client yoksa seed patlar)"
pnpm -s prisma generate --schema prisma/schema.prisma >/dev/null
echo "✅ prisma generate OK"
echo

echo "==> 3) DB'ye CONSULTANT seed et (Prisma direct)"
# Burada amaç: match için sistemde en az 1 consultant/user oluşturmak.
# Şema farklıysa prisma error mesajına göre otomatik olarak alan ekleyip retry yapıyoruz.
node - <<'NODE'
const crypto = require("crypto");
const { PrismaClient } = require("@prisma/client");

const datasourceUrl = process.env.DATABASE_URL;
if (!datasourceUrl) {
  console.error("DATABASE_URL missing");
  process.exit(2);
}

const prisma = new PrismaClient({ datasourceUrl });

const rand = () => crypto.randomBytes(4).toString("hex");
const email = `seed.consultant.${Date.now()}.${rand()}@local.test`;

const attempts = [
  // en minimal
  () => ({ email, role: "CONSULTANT" }),

  // yaygın alanlar
  () => ({ email, role: "CONSULTANT", name: "Seed Consultant" }),
  () => ({ email, role: "CONSULTANT", fullName: "Seed Consultant" }),
  () => ({ email, role: "CONSULTANT", phone: "5000000000" }),
  () => ({ email, role: "CONSULTANT", isActive: true }),
  () => ({ email, role: "CONSULTANT", status: "ACTIVE" }),

  // auth şeması varsa (hash field isimleri değişebilir)
  () => ({ email, role: "CONSULTANT", passwordHash: "seed" }),
  () => ({ email, role: "CONSULTANT", password: "seed" }),
];

async function main() {
  // Model adını tahmin: çoğu projede User.
  // Eğer model farklıysa, prisma error mesajı bunu söyler.
  let lastErr = null;

  for (let i = 0; i < attempts.length; i++) {
    const data = attempts[i]();
    try {
      const created = await prisma.user.create({ data });
      console.log("✅ SEEDED USER:");
      console.log(JSON.stringify({ id: created.id, email: created.email, role: created.role }, null, 2));
      return;
    } catch (e) {
      lastErr = e;
      // Prisma error’ı okunabilir bas
      const msg = e?.message || String(e);
      // Bazı projelerde model "User" değilse burada anlaşılır
      if (msg.includes("prisma.user")) {
        // devam et
      }
      // Hızlı debug için sadece özet bas
      console.log(`- attempt ${i+1}/${attempts.length} failed: ${msg.split("\n")[0]}`);
    }
  }

  console.error("❌ SEED FAILED (all attempts). Last error:");
  console.error(lastErr?.message || lastErr);
  process.exit(3);
}

main()
  .finally(async () => prisma.$disconnect());
NODE

cd - >/dev/null
echo

echo "==> 4) Yeni lead+deal üret ve match dene"
LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{ "initialText": "seed consultant then match" }')"
LEAD_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$LEAD_JSON")"

DEAL_JSON="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID")"
DEAL_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$DEAL_JSON")"

echo "LEAD_ID=$LEAD_ID"
echo "DEAL_ID=$DEAL_ID"
echo

MATCH_RESP="$(curl -sS -X POST "$BASE_URL/deals/$DEAL_ID/match" || true)"
echo "Match response: $MATCH_RESP"
echo
echo "✅ DONE"
