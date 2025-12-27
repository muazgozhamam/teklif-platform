#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="apps/dashboard/.env.local"

echo "==> Dashboard env ayarlanıyor"

mkdir -p apps/dashboard

if [[ -f "$ENV_FILE" ]]; then
  grep -v '^NEXT_PUBLIC_API_BASE_URL=' "$ENV_FILE" > "$ENV_FILE.tmp"
  mv "$ENV_FILE.tmp" "$ENV_FILE"
fi

echo "NEXT_PUBLIC_API_BASE_URL=http://localhost:3001" >> "$ENV_FILE"

echo "✅ $ENV_FILE:"
cat "$ENV_FILE"
