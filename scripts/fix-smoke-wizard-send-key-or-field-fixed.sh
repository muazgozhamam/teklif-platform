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

# 1) Find the exact FIELD extraction line (string match)
lines = txt.splitlines()
new_lines = []
replaced = False
for line in lines:
    if 'FIELD="$(echo "$Q" | node -e' in line and 'j.field' in line:
        # Replace with KEY+FIELD extraction + fallback
        new_lines.append(
            '  KEY="$(echo "$Q" | node -e \'const fs=require("fs"); const j=JSON.parse(fs.readFileSync(0,"utf8")); process.stdout.write((j.key||"").toString());\')"'
        )
        new_lines.append(
            '  FIELD="$(echo "$Q" | node -e \'const fs=require("fs"); const j=JSON.parse(fs.readFileSync(0,"utf8")); process.stdout.write((j.field||"").toString());\')"'
        )
        new_lines.append('  [ -n "$KEY" ] || KEY="$FIELD"')
        new_lines.append('  [ -n "$FIELD" ] || FIELD="$KEY"')
        replaced = True
    else:
        new_lines.append(line)

if not replaced:
    raise SystemExit("❌ Could not find FIELD extraction line to patch")

txt = "\n".join(new_lines)

# 2) Update answer POST body: include key and field
txt = txt.replace('-d "{\"answer\":\"$A\"}"', '-d "{\"key\":\"$KEY\",\"field\":\"$FIELD\",\"answer\":\"$A\"}"')

bak = p.with_suffix(p.suffix + ".sendkey.fixed.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(txt, encoding="utf-8")

print("✅ Patched smoke: send key/field/answer to wizard/answer")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Run smoke"
bash "$ROOT/scripts/smoke-wizard-to-match-mac.sh"
