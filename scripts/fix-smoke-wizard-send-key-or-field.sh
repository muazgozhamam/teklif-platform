#!/usr/bin/env bash
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR/.." && pwd)"

if [ ! -f "$ROOT/pnpm-workspace.yaml" ]; then
  echo "❌ Repo root bulunamadı (pnpm-workspace.yaml yok). ROOT=$ROOT"
  exit 1
fi

FILE="$ROOT/scripts/smoke-wizard-to-match-mac.sh"
if [ ! -f "$FILE" ]; then
  echo "❌ Missing: $FILE"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re

p = Path("scripts/smoke-wizard-to-match-mac.sh")
txt = p.read_text(encoding="utf-8")
orig = txt

# 1) Replace FIELD extraction line with KEY+FIELD extraction and fallback
# Original:
# FIELD="$(echo "$Q" | node -e '... j.field ...')"
pattern_field = r'^\s*FIELD="\$\(echo "\$Q" \| node -e \'const fs=require\("fs"\); const j=JSON\.parse\(fs\.readFileSync\(0,"utf8"\)\); process\.stdout\.write\(j\.field\|\|"");\'\)"\s*$'
m = re.search(pattern_field, txt, flags=re.M)
if not m:
    raise SystemExit("❌ Could not find the FIELD extraction line in smoke script (pattern mismatch).")

replacement = (
    '  KEY="$(echo "$Q" | node -e \'const fs=require("fs"); const j=JSON.parse(fs.readFileSync(0,"utf8")); '
    'process.stdout.write((j.key||"").toString());\')"\n'
    '  FIELD="$(echo "$Q" | node -e \'const fs=require("fs"); const j=JSON.parse(fs.readFileSync(0,"utf8")); '
    'process.stdout.write((j.field||"").toString());\')"\n'
    '  [ -n "$KEY" ] || KEY="$FIELD"\n'
)

# Keep indentation similar: the original line already had two spaces before FIELD= in file
txt = re.sub(pattern_field, replacement.rstrip("\n"), txt, flags=re.M)

# 2) Update "field missing" guard to check KEY instead
txt = re.sub(
    r'if \[ -z "\$FIELD" \]; then\s*\n\s*echo "Not: field gelmedi \(muhtemelen wizard done\)\."\s*\n\s*break\s*\n\s*fi',
    'if [ -z "$KEY" ]; then\n    echo "Not: key/field gelmedi (muhtemelen wizard done)."\n    break\n  fi',
    txt,
    flags=re.M
)

# 3) Ensure answer_for_field uses FIELD (kept) and if KEY set but FIELD empty, derive FIELD=KEY
# Add after fallback line: [ -n "$FIELD" ] || FIELD="$KEY"
if '[ -n "$FIELD" ] || FIELD="$KEY"' not in txt:
    txt = txt.replace('[ -n "$KEY" ] || KEY="$FIELD"\n', '[ -n "$KEY" ] || KEY="$FIELD"\n  [ -n "$FIELD" ] || FIELD="$KEY"\n')

# 4) Update POST body to include key and field
# Original: -d "{\"answer\":\"$A\"}"
txt2 = re.sub(
    r'-d "\{\\"answer\\":\\"\$A\\"\}"',
    r'-d "{\"key\":\"$KEY\",\"field\":\"$FIELD\",\"answer\":\"$A\"}"',
    txt
)
txt = txt2

if txt == orig:
    raise SystemExit("❌ No changes applied (unexpected).")

bak = p.with_suffix(p.suffix + ".sendkey.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(txt, encoding="utf-8")

print("✅ Patched smoke: extract key fallback + send key/field/answer to wizard/answer")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Run smoke"
bash "$ROOT/scripts/smoke-wizard-to-match-mac.sh"
