#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Desktop/teklif-platform"
SMOKE="$ROOT/scripts/smoke-wizard-to-match-mac.sh"

[ -f "$SMOKE" ] || { echo "❌ Smoke script bulunamadı: $SMOKE"; exit 1; }

cp "$SMOKE" "$SMOKE.answerjson.bak"
echo "✅ Backup created: $SMOKE.answerjson.bak"

# Patch: POST body -> inline answer_for_field call
# Önce eski -d satırını bulup değiştir
sed -i '' 's/-d "{\\"key\\":\\"$FIELD\\",\\"field\\":\\"$FIELD\\",\\"answer\\":\\"$A\\"}"/-d "{\\"key\\":\\"$FIELD\\",\\"field\\":\\"$FIELD\\",\\"answer\\":\\"$(answer_for_field \"$FIELD\")\\"}"/' "$SMOKE"

echo "✅ Smoke script patched: wizard/answer POST -> inline answer_for_field"

# Opsiyonel: çalıştır ve test et
bash "$SMOKE"
