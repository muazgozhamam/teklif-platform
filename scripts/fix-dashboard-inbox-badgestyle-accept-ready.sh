#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/consultant/inbox/page.tsx"
[ -f "$FILE" ] || { echo "❌ Missing: $FILE"; exit 1; }

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/dashboard/app/consultant/inbox/page.tsx")
orig = p.read_text(encoding="utf-8")

# badgeStyle(...) param union includes 'other' but not 'ready' -> add it
# Example target: function badgeStyle(kind: 'open' | 'claimed' | 'linked' | 'other') { ... }
pat = r"(function\s+badgeStyle\s*\(\s*kind\s*:\s*'open'\s*\|\s*'claimed'\s*\|\s*'linked'\s*\|\s*)'other'(\s*\))"
m = re.search(pat, orig)
if not m:
    raise SystemExit("❌ Pattern not found: badgeStyle(kind: 'open'|'claimed'|'linked'|'other')")

new = re.sub(pat, r"\1'ready' | 'other'\2", orig, count=1)

if new == orig:
    raise SystemExit("❌ No changes applied (unexpected).")

bak = p.with_suffix(p.suffix + ".badgestyle-ready.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(new, encoding="utf-8")

print("✅ Patched badgeStyle(): added 'ready' to kind union")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Next build re-check"
pnpm -C apps/dashboard -s build
echo "✅ Done."
