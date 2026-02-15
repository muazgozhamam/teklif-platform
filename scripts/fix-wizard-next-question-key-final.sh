#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="$ROOT/apps/api/src/leads/leads.service.ts"

[ -f "$FILE" ] || { echo "❌ leads.service.ts bulunamadı"; exit 1; }

# Backup
cp "$FILE" "$FILE.keyfinal.bak"
echo "✅ Backup created at $FILE.keyfinal.bak"

# Manuel patch: return objesine key ekle
# field varsa key: field ekle
sed -i '' 's/return { done: false, \(field[^\}]*\) }/return { done: false, key: \1, \1 }/' "$FILE"
echo "✅ Wizard next-question return objesine key eklendi (final fix)"

# Build
pnpm -C "$ROOT/apps/api" -s build
echo "✅ Build done"
