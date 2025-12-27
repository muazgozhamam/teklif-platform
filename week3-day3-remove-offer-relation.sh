#!/usr/bin/env bash
set -euo pipefail

SCHEMA="apps/api/prisma/schema.prisma"

if [ ! -f "$SCHEMA" ]; then
  echo "ERROR: $SCHEMA bulunamadı."
  exit 1
fi

echo "==> Removing Offer.request relation line (Request type) ..."

# Offer bloğu içinde "request       Request @relation(...)" satırını sil
perl -0777 -i -pe '
s/(model\s+Offer\s*\{.*?\n)\s*request\s+Request\s+@relation\([^\n]*\)\s*\n/$1/s
' "$SCHEMA"

echo "==> Showing Offer block (quick check):"
sed -n '120,160p' "$SCHEMA"

echo "==> prisma validate..."
cd apps/api
pnpm exec prisma validate
echo "==> prisma validate OK"
