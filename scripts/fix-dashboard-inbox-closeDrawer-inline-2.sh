#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/consultant/inbox/page.tsx"
[ -f "$FILE" ] || { echo "❌ Missing: $FILE"; exit 1; }

python3 - <<'PY'
from pathlib import Path

p = Path("apps/dashboard/app/consultant/inbox/page.tsx")
orig = p.read_text(encoding="utf-8")

needle = "onClick={() => closeDrawer()}"
replacement = "onClick={() => { setDrawerOpen(false); setSelectedId(null); setSelected(null); }}"

# 2. occurrence
new = orig.replace(needle, replacement, 2)

if new == orig or new.count(needle) == orig.count(needle):
    raise SystemExit("❌ Could not replace second closeDrawer() occurrence (pattern mismatch).")

bak = p.with_suffix(p.suffix + ".closedrawer-inline2.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(new, encoding="utf-8")

print("✅ Inlined closeDrawer() (second occurrence) into onClick")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Next build re-check"
pnpm -C apps/dashboard -s build
echo "✅ Done."
