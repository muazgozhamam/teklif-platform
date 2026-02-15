#!/usr/bin/env bash
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR/.." && pwd)"
FILE="$ROOT/scripts/smoke-wizard-to-match-mac.sh"

if [ ! -f "$FILE" ]; then
  echo "❌ Missing: $FILE"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

p = Path("scripts/smoke-wizard-to-match-mac.sh")
txt = p.read_text(encoding="utf-8")
orig = txt

# Replace POST body line with key removed, only field+answer
# Original: -d "{\"key\":\"$KEY\",\"field\":\"$FIELD\",\"answer\":\"$A\"}"
txt = txt.replace(
    '-d "{\"key\":\"$KEY\",\"field\":\"$FIELD\",\"answer\":\"$A\"}"',
    '-d "{\"field\":\"$FIELD\",\"answer\":\"$A\"}"'
)

bak = p.with_suffix(p.suffix + ".fieldonly.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(txt, encoding="utf-8")

print("✅ Patched smoke script: send only field+answer to wizard/answer")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Run smoke"
bash "$ROOT/scripts/smoke-wizard-to-match-mac.sh"
