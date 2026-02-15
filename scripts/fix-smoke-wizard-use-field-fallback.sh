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

# Replace jq lookups for .key with fallback .key // .field
# Covers common patterns like: jq -r '.key'  or jq -r ".key"
txt = re.sub(r"jq(\s+-r)?\s+(['\"])\\.key\\2", r"jq\1 \2.key // .field\2", txt)

# Also cover jq -r '.key // ...' already (avoid double changes) - above won't match those.
# If no change, try a more general replacement: any ".key" token inside jq filter-only lines
if txt == orig:
    txt = re.sub(r"(jq[^\n]*-r[^\n]*['\"][^'\"]*)\.key([^'\"]*['\"])",
                 r"\1.key // .field\2",
                 txt)

if txt == orig:
    raise SystemExit("❌ No changes applied (could not find jq '.key' usage).")

bak = p.with_suffix(p.suffix + ".fieldfallback.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(txt, encoding="utf-8")

print("✅ Patched smoke script: use .key // .field for wizard question key extraction")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Run smoke"
bash "$ROOT/scripts/smoke-wizard-to-match-mac.sh"
