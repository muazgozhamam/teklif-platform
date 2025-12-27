#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_DIR="$ROOT/apps/api"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"

cd "$API_DIR"

EMAIL="${EMAIL:-consultant1@test.com}"
PASS="${PASS:-pass123}"
NAME="${NAME:-Consultant 1}"
ID="${ID:-consultant_seed_1}"

echo "==> Upsert CONSULTANT via prisma db execute"
pnpm -s prisma db execute --schema prisma/schema.prisma --stdin <<SQL
INSERT INTO "User" ("id","email","password","name","role","createdAt","updatedAt")
VALUES (
  '${ID}',
  '${EMAIL}',
  '${PASS}',
  '${NAME}',
  'CONSULTANT'::"Role",
  now(),
  now()
)
ON CONFLICT ("email")
DO UPDATE SET
  "role" = 'CONSULTANT'::"Role",
  "updatedAt" = now();
SQL

echo "✅ Consultant ensured:"
echo "  email=$EMAIL"
echo "  id=$ID"
