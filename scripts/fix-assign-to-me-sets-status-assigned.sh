#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
FILE="$ROOT/apps/api/src/deals/deals.service.ts"

[ -f "$FILE" ] || { echo "❌ Missing: $FILE"; exit 1; }

python3 - <<'PY'
from pathlib import Path
import re, sys

p = Path("apps/api/src/deals/deals.service.ts")
orig = p.read_text(encoding="utf-8")

# We expect assignToMe update block contains: data: { consultantId: userId },
# Patch it to also set status: 'ASSIGNED'
pat = r"(async\s+assignToMe\([\s\S]*?\)\s*\{[\s\S]*?return\s+await\s+\(this\.prisma\s+as\s+any\)\.deal\.update\(\{\s*[\s\S]*?data:\s*\{\s*)(consultantId:\s*userId\s*)(\}\s*,)"
m = re.search(pat, orig)
if not m:
    raise SystemExit("❌ Pattern mismatch: could not locate assignToMe() deal.update data block.")

repl = m.group(1) + m.group(2) + ", status: 'ASSIGNED' " + m.group(3)
new = re.sub(pat, repl, orig, count=1)

if new == orig:
    raise SystemExit("❌ No changes applied (unexpected).")

bak = p.with_suffix(p.suffix + ".assigntome-status.bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(new, encoding="utf-8")

print("✅ Patched assignToMe(): set status='ASSIGNED' when claiming")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> API build"
pnpm -C apps/api -s build
echo "✅ Done."
