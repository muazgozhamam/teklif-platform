#!/usr/bin/env bash
set -euo pipefail

FILE="apps/api/src/deals/deals.service.ts"
[ -f "$FILE" ] || { echo "❌ Missing: $FILE"; exit 1; }

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/deals/deals.service.ts")
orig = p.read_text(encoding="utf-8")

# Replace the exact where clause for listMineInbox
pat = r"where:\s*\{\s*status:\s*'OPEN'\s*,\s*consultantId:\s*userId\s*\}"
if not re.search(pat, orig):
    raise SystemExit("❌ Pattern not found for listMineInbox where clause (expected status:'OPEN', consultantId:userId).")

new = re.sub(
    pat,
    "where: { status: { in: ['OPEN','ASSIGNED'] }, consultantId: userId }",
    orig,
    count=1
)

bak = p.with_suffix(p.suffix + ".mineinbox.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(new, encoding="utf-8")

print("✅ Updated listMineInbox to include OPEN + ASSIGNED")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> API build"
pnpm -C apps/api -s build
echo "✅ Done."
