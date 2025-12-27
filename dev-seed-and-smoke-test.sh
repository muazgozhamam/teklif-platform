#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$ROOT_DIR/apps/api"
BASE_URL="${BASE_URL:-http://localhost:3001}"

say() { printf "\n==> %s\n" "$*"; }
die() { echo "❌ $*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "Komut yok: $1"; }

need curl
need node
need pnpm

HAS_JQ=0
if command -v jq >/dev/null 2>&1; then HAS_JQ=1; fi

load_env() {
  local f
  for f in "$API_DIR/.env" "$API_DIR/.env.local" "$ROOT_DIR/.env" "$ROOT_DIR/.env.local"; do
    if [[ -f "$f" ]]; then
      # shellcheck disable=SC1090
      set -a; source "$f"; set +a
    fi
  done
}

load_env

say "0) API health"
curl -sS "$BASE_URL/health" >/dev/null || die "API ayakta değil: $BASE_URL/health"
echo "✅ health OK"

say "1) Prisma generate"
pushd "$API_DIR" >/dev/null
pnpm -s prisma generate --schema prisma/schema.prisma >/dev/null
popd >/dev/null
echo "✅ prisma generate OK"

say "2) DB seed: ADMIN + CONSULTANT1 role fix + CONSULTANT2 create (Prisma adapter-pg)"
mkdir -p "$API_DIR/prisma/seed"

cat > "$API_DIR/prisma/seed/dev.seed.js" <<'NODE'
const { Pool } = require("pg");
const { PrismaClient } = require("@prisma/client");
const { PrismaPg } = require("@prisma/adapter-pg");
const bcrypt = require("bcryptjs");

function norm(s){ return String(s || "").trim().replace(/^["']|["']$/g, ""); }

async function upsertUser(prisma, { email, passwordPlain, name, role }) {
  const passwordHash = await bcrypt.hash(passwordPlain, 10);
  const existing = await prisma.user.findUnique({ where: { email } });

  const data = { email, password: passwordHash, name, role };

  if (existing) {
    const u = await prisma.user.update({ where: { email }, data });
    return { action: "updated", user: u };
  } else {
    const u = await prisma.user.create({ data });
    return { action: "created", user: u };
  }
}

(async () => {
  const dbUrl = norm(process.env.DATABASE_URL);
  if (dbUrl.length === 0) throw new Error("DATABASE_URL missing");

  const pool = new Pool({ connectionString: dbUrl });
  const adapter = new PrismaPg(pool);
  const prisma = new PrismaClient({ adapter });

  // ADMIN
  const admin = await upsertUser(prisma, {
    email: "admin@local.test",
    passwordPlain: "Admin1234!",
    name: "Local Admin",
    role: "ADMIN",
  });

  // CONSULTANT1 (varsa role fix)
  const c1 = await upsertUser(prisma, {
    email: "consultant@local.test",
    passwordPlain: "Consultant123!",
    name: "Local Consultant",
    role: "CONSULTANT",
  });

  // CONSULTANT2
  const c2 = await upsertUser(prisma, {
    email: "consultant2@local.test",
    passwordPlain: "Consultant123!",
    name: "Local Consultant 2",
    role: "CONSULTANT",
  });

  console.log("✅ Seed OK");
  console.log("ADMIN:", { action: admin.action, id: admin.user.id, email: admin.user.email, role: admin.user.role });
  console.log("C1   :", { action: c1.action, id: c1.user.id, email: c1.user.email, role: c1.user.role });
  console.log("C2   :", { action: c2.action, id: c2.user.id, email: c2.user.email, role: c2.user.role });

  await prisma.$disconnect();
  await pool.end();
})().catch((e) => {
  console.error("SEED ERROR:", e?.message || e);
  process.exit(2);
});
NODE

pushd "$API_DIR" >/dev/null
pnpm -s add -D bcryptjs >/dev/null 2>&1 || true
pnpm -s prisma generate --schema prisma/schema.prisma >/dev/null
node prisma/seed/dev.seed.js
popd >/dev/null

say "3) Admin login -> token al"
LOGIN_JSON="$(curl -sS -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@local.test","password":"Admin1234!"}')"
ADMIN_TOKEN="$(node -p 'JSON.parse(process.argv[1]).access_token || ""' "$LOGIN_JSON")"
[[ -n "${ADMIN_TOKEN:-}" ]] || die "Login başarısız. Response: $LOGIN_JSON"
echo "✅ ADMIN_TOKEN len=${#ADMIN_TOKEN}"

say "4) E2E: Lead -> Deal -> Match"
LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{ "initialText": "dev smoke test" }')"
LEAD_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$LEAD_JSON")"

DEAL_JSON="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID")"
DEAL_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$DEAL_JSON")"

echo "LEAD_ID=$LEAD_ID"
echo "DEAL_ID=$DEAL_ID"

MATCH_JSON="$(curl -sS -X POST "$BASE_URL/deals/$DEAL_ID/match" || true)"
echo "Match response: $MATCH_JSON"

say "5) Deal'i çek (ASSIGNED doğrula)"
DEAL_FULL="$(curl -sS "$BASE_URL/deals/$DEAL_ID")"
if [[ "$HAS_JQ" -eq 1 ]]; then
  echo "$DEAL_FULL" | jq
else
  echo "$DEAL_FULL"
fi

STATUS="$(node -p 'JSON.parse(process.argv[1]).status || ""' "$DEAL_FULL")"
[[ "$STATUS" == "ASSIGNED" ]] || die "Deal ASSIGNED olmadı (status=$STATUS)"

say "✅ DONE"
echo "Özet:"
echo "- ADMIN: admin@local.test / Admin1234!"
echo "- CONSULTANT: consultant@local.test / Consultant123!"
echo "- CONSULTANT2: consultant2@local.test / Consultant123!"
echo "- LEAD_ID=$LEAD_ID"
echo "- DEAL_ID=$DEAL_ID"
