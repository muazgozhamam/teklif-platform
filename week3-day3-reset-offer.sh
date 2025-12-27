#!/usr/bin/env bash
set -euo pipefail

# Defaults (istersen argümanla değiştir)
PROVIDER_ID="${1:-provider_demo}"
REQUEST_ID="${2:-test_request_1}"

API_DIR="apps/api"

if [ ! -d "$API_DIR" ]; then
  echo "ERROR: $API_DIR bulunamadı. Proje kökünde misin?"
  exit 1
fi

echo "==> Deleting offer where providerId='$PROVIDER_ID' AND requestId='$REQUEST_ID'"

cd "$API_DIR"

# SQLite + Prisma: doğrudan SQL çalıştır
pnpm exec prisma db execute --stdin <<SQL
DELETE FROM "Offer"
WHERE "providerId" = '$PROVIDER_ID'
  AND "requestId" = '$REQUEST_ID';
SQL

echo "==> Done. Remaining offers for requestId='$REQUEST_ID':"
pnpm exec prisma db execute --stdin <<SQL
SELECT "id","providerId","requestId","price","status","createdAt"
FROM "Offer"
WHERE "requestId" = '$REQUEST_ID'
ORDER BY "createdAt" DESC;
SQL

echo "==> OK. Artık UI'dan tekrar teklif gönderebilirsin."
