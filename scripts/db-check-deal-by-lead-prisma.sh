#!/usr/bin/env bash
set -euo pipefail

LEAD_ID="${1:-}"
if [[ -z "$LEAD_ID" ]]; then
  echo "Usage: bash scripts/db-check-deal-by-lead-prisma.sh <LEAD_ID>"
  exit 1
fi

cd "$(pwd)/apps/api"

pnpm -s prisma db execute --config prisma.config.ts --stdin <<SQL
SELECT id, status, city, district, type, rooms, leadId, createdAt, updatedAt
FROM Deal
WHERE leadId = '$LEAD_ID';
SQL
