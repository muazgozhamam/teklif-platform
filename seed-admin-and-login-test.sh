#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
API_DIR="$ROOT_DIR/apps/api"

# env load
if [[ -f "$API_DIR/.env" ]]; then set -a; source "$API_DIR/.env"; set +a; fi
if [[ -f "$API_DIR/.env.local" ]]; then set -a; source "$API_DIR/.env.local"; set +a; fi
: "${DATABASE_URL:?DATABASE_URL yok (apps/api/.env veya .env.local içinde olmalı)}"

mkdir -p "$API_DIR/prisma/seed"

cat > "$API_DIR/prisma/seed/admin.seed.js" <<'NODE'
const { Pool } = require("pg");
const { PrismaClient } = require("@prisma/client");
const { PrismaPg } = require("@prisma/adapter-pg");
const bcrypt = require("bcryptjs");

function norm(s){ return String(s || "").trim().replace(/^["']|["']$/g, ""); }

(async () => {
  const dbUrl = norm(process.env.DATABASE_URL);
  const pool = new Pool({ connectionString: dbUrl });
  const adapter = new PrismaPg(pool);
  const prisma = new PrismaClient({ adapter });

  const email = "admin@local.test";
  const plain = "Admin1234!";
  const hash = await bcrypt.hash(plain, 10);

  const existing = await prisma.user.findUnique({ where: { email } });

  if (existing) {
    const updated = await prisma.user.update({
      where: { email },
      data: { role: "ADMIN", password: hash, name: existing.name ?? "Local Admin" },
    });
    console.log("✅ Admin updated:", { id: updated.id, email: updated.email, role: updated.role, password: plain });
  } else {
    const created = await prisma.user.create({
      data: { email, password: hash, name: "Local Admin", role: "ADMIN" },
    });
    console.log("✅ Admin created:", { id: created.id, email: created.email, role: created.role, password: plain });
  }

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

node prisma/seed/admin.seed.js
popd >/dev/null

echo
echo "==> Login test"
curl -sS -X POST http://localhost:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@local.test","password":"Admin1234!"}' | sed 's/\\n/\n/g'
echo
