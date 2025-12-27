#!/usr/bin/env bash
set -euo pipefail

SCHEMA="apps/api/prisma/schema.prisma"

echo "==> Removing enum OfferStatus (SQLite compatibility)"

# Enum bloğunu tamamen sil
perl -0777 -i -pe '
s/enum\s+OfferStatus\s*\{.*?\}\s*//sg
' "$SCHEMA"

# status alanını String'e çevir
perl -i -pe '
s/status\s+OfferStatus\s+@default\(PENDING\)/status String @default("PENDING")/
' "$SCHEMA"

echo "==> Updated schema (preview):"
sed -n '110,160p' "$SCHEMA"

echo "==> prisma validate..."
cd apps/api
pnpm exec prisma validate
echo "==> prisma validate OK"
