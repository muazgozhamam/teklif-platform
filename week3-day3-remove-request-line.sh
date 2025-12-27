#!/usr/bin/env bash
set -euo pipefail

SCHEMA="apps/api/prisma/schema.prisma"

if [ ! -f "$SCHEMA" ]; then
  echo "ERROR: $SCHEMA bulunamadı."
  exit 1
fi

echo "==> Removing any line: request  Request  @relation(...)"

# Satır bazlı: request Request @relation içeren satırı sil
perl -i -ne '
  next if /^\s*request\s+Request\s+@relation\(/;
  print;
' "$SCHEMA"

echo "==> Quick check (Offer block):"
sed -n '120,160p' "$SCHEMA"

echo "==> prisma validate..."
cd apps/api
pnpm exec prisma validate
echo "==> prisma validate OK"
