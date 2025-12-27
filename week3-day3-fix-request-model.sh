#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"
SERVICE="$API_DIR/src/offers/offers.service.ts"

if [ ! -f "$SCHEMA" ]; then
  echo "ERROR: schema.prisma bulunamadı: $SCHEMA"
  exit 1
fi

echo "==> Detecting request-like model name from schema.prisma ..."

MODELS=$(perl -ne 'if(/^model\s+(\w+)\s*\{/){print "$1\n"}' "$SCHEMA" | tr -d '\r')

# Adaylar (öncelik)
CANDIDATES=("ServiceRequest" "JobRequest" "UserRequest" "Demand" "Task" "Ticket" "Inquiry" "Order" "Job" "Work" "Lead")

FOUND=""

for c in "${CANDIDATES[@]}"; do
  if echo "$MODELS" | grep -qx "$c"; then
    FOUND="$c"
    break
  fi
done

# request geçen ilk model
if [ -z "$FOUND" ]; then
  FOUND=$(echo "$MODELS" | grep -i "request" | head -n 1 || true)
fi

if [ -z "$FOUND" ]; then
  echo "ERROR: Schema içinde request benzeri model bulunamadı."
  echo "Mevcut modeller:"
  echo "$MODELS"
  exit 1
fi

echo "==> Using request model: $FOUND"

# schema.prisma relation satırını düzelt
perl -0777 -i -pe "s/(\\brequest\\s+)(Request)(\\s+@relation\\(fields:\\s*\\[requestId\\],\\s*references:\\s*\\[id\\][^\\)]*\\))/\$1$FOUND\$3/g" "$SCHEMA"

# Prisma delegate: lowerCamel (bash ile)
first="${FOUND:0:1}"
rest="${FOUND:1}"
LOWER="$(echo "$first" | tr '[:upper:]' '[:lower:]')$rest"

# offers.service.ts içindeki prisma.request'i düzelt
if [ -f "$SERVICE" ]; then
  perl -0777 -i -pe "s/this\\.prisma\\.request\\b/this.prisma.$LOWER/g" "$SERVICE"
  echo "==> Updated offers.service.ts prisma delegate: request -> $LOWER"
fi

echo "==> Running prisma validate..."
cd "$API_DIR"
pnpm exec prisma validate
echo "==> prisma validate OK"
