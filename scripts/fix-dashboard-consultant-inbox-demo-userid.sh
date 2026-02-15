#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
FILE="$ROOT/apps/dashboard/app/consultant/inbox/page.tsx"
NEW_ID="cmk0380hs0000a3lwug4f5b2k"

[ -f "$FILE" ] || { echo "❌ Missing: $FILE"; exit 1; }

python3 - <<PY
from pathlib import Path
p = Path("$FILE")
orig = p.read_text(encoding="utf-8")

bak = p.with_suffix(p.suffix + ".demo-userid.bak")
bak.write_text(orig, encoding="utf-8")

# Replace ALL occurrences of consultant_seed_1 with the real seeded consultant user id
new = orig.replace("consultant_seed_1", "$NEW_ID")

if new == orig:
    raise SystemExit("❌ No changes applied (consultant_seed_1 not found).")

p.write_text(new, encoding="utf-8")
print("✅ Updated consultant inbox demo user id")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Dashboard build check"
pnpm -C apps/dashboard -s build
echo "✅ Done."
