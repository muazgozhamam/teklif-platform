#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"

if [ ! -f "$SCHEMA" ]; then
  echo "ERROR: schema.prisma bulunamadı: $SCHEMA"
  exit 1
fi

# Hedef model adı (şimdilik Lead; sonra gerekirse tek komutla değiştiririz)
FOUND="Lead"

echo "==> Forcing Offer.request relation type => $FOUND"

# model Offer { ... } bloğu içinde "request   Request" geçen yeri ne olursa olsun değiştir
perl -0777 -i -pe "
s/(model\\s+Offer\\s*\\{.*?\\n\\s*request\\s+)(Request)(\\s+@relation\\([^\\n]*\\)\\s*\\n)/\$1$FOUND\$3/sg
" "$SCHEMA"

echo "==> Verifying change..."
grep -n \"model Offer\" -n "$SCHEMA" | head -n 3 || true
grep -n \"request\" "$SCHEMA" | grep -n \"Offer\" -n >/dev/null 2>&1 || true

echo "==> Running prisma validate..."
cd "$API_DIR"
pnpm exec prisma validate
echo "==> prisma validate OK"
