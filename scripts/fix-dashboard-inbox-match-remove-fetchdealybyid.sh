#!/usr/bin/env bash
set -euo pipefail

FILE="apps/dashboard/app/consultant/inbox/page.tsx"
[ -f "$FILE" ] || { echo "❌ Missing: $FILE"; exit 1; }

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/dashboard/app/consultant/inbox/page.tsx")
orig = p.read_text(encoding="utf-8")

# Remove the finalize refresh block inside matchDeal that references fetchDealById,
# since we already reload the page after match.
pat = r"""
\s*try\s*\{\s*
\s*if\s*\(selectedId\s*&&\s*String\(selectedId\)\s*==\s*String\(dealId\)\)\s*\{\s*
\s*const\s+d2\s*=\s*await\s+fetchDealById\(dealId\);\s*
\s*setSelected\(d2\);\s*
\s*\}\s*
\s*\}\s*catch\s*\{\s*
\s*//\s*ignore\s*finalize\s*refresh\s*errors\s*
\s*\}\s*
"""
m = re.search(pat, orig, flags=re.S | re.X)
if not m:
    raise SystemExit("❌ Pattern not found: matchDeal finalize refresh block (fetchDealById).")

new = orig[:m.start()] + "\n" + orig[m.end():]

bak = p.with_suffix(p.suffix + ".rm-fetchdealybyid.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(new, encoding="utf-8")

print("✅ Removed matchDeal finalize refresh block that referenced fetchDealById()")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Next build re-check"
pnpm -C apps/dashboard -s build
echo "✅ Done."
