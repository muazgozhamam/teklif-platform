#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="$ROOT/apps/api/src/leads/leads.service.ts"

if [ ! -f "$FILE" ]; then
  echo "❌ leads.service.ts bulunamadı"
  exit 1
fi

# Manuel patch: belirli satırları değiştir
# Örn: line 200 civarı return { done:false, field, question };
# bunu return { done:false, key: field, field, question }; yap

# Önce backup
cp "$FILE" "$FILE.manualfix.bak"

# patch komutu (sed)
sed -i '' 's/return { done: false, field, question }/return { done: false, key: field, field, question }/' "$FILE"

echo "✅ Wizard next-question return objesine key eklendi (manuel fix)"
echo " - Backup :", "$FILE.manualfix.bak"

# Build
pnpm -C "$ROOT/apps/api" -s build
echo "✅ Build done"
