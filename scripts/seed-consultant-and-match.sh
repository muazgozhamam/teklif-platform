#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_DIR="$ROOT/apps/api"

EMAIL="${EMAIL:-consultant1@test.com}"
PASS="${PASS:-pass123}"
NAME="${NAME:-Consultant 1}"
ID="${ID:-consultant_seed_1}"

DEAL_ID="${DEAL_ID:-}"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"
echo "EMAIL=$EMAIL"

cd "$API_DIR"

echo "==> 0) sanity: prisma db execute help (should NOT mention --schema)"
pnpm -s prisma db execute -h | sed -n '1,25p' || true
echo

echo "==> 1) Seed/Upsert consultant via prisma db execute (stdin)"
pnpm -s prisma db execute --stdin <<SQL
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

echo
echo "==> 2) Verify consultant exists"
pnpm -s prisma db execute --stdin <<'SQL'
SELECT id, email, role, "createdAt"
FROM "User"
WHERE role = 'CONSULTANT'::"Role"
ORDER BY "createdAt" ASC;
SQL

echo
echo "==> 3) If DEAL_ID provided, call match endpoint"
if [[ -n "$DEAL_ID" ]]; then
  echo "Using DEAL_ID=$DEAL_ID"
  curl -sS -X POST "http://localhost:3001/deals/$DEAL_ID/match" -H "Content-Type: application/json"
  echo
else
  echo "DEAL_ID not provided. Rerun with:"
  echo "  DEAL_ID=<id> $ROOT/scripts/seed-consultant-and-match.sh"
fi
