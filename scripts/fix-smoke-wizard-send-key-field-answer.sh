#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SMOKE="$ROOT/scripts/smoke-wizard-to-match-mac.sh"

if [ ! -f "$SMOKE" ]; then
  echo "❌ Smoke script bulunamadı: $SMOKE"
  exit 1
fi

cp "$SMOKE" "$SMOKE.keyfieldanswer.bak"

# Patch: wizard/answer POST body
# Orijinal: -d "{\"answer\":\"$A\"}"
# Yeni: -d "{\"key\":\"$FIELD\",\"field\":\"$FIELD\",\"answer\":\"$A\"}"
sed -i '' 's/-d "{\\"answer\\":\\"$A\\"}"/-d "{\\"key\\":\\"$FIELD\\",\\"field\\":\\"$FIELD\\",\\"answer\\":\\"$A\\"}"/' "$SMOKE"

echo "✅ Smoke script patched: wizard/answer -> send key + field + answer"
echo " - Backup:", "$SMOKE.keyfieldanswer.bak"

# Opsiyonel: test çalıştır
bash "$SMOKE"
