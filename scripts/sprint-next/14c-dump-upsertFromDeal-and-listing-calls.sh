#!/usr/bin/env bash
set -euo pipefail

# ÇALIŞMA KÖKÜ
cd ~/Desktop/teklif-platform

SVC="apps/api/src/listings/listings.service.ts"
test -f "$SVC" || { echo "ERR: missing $SVC"; exit 1; }

echo "==> FILE: $SVC"
echo

echo "==> 1) upsertFromDeal() line number"
python3 - <<'PY'
from pathlib import Path
import re
p = Path("apps/api/src/listings/listings.service.ts")
txt = p.read_text(encoding="utf-8").splitlines()
for i,line in enumerate(txt, start=1):
    if re.search(r"\bupsertFromDeal\b", line):
        print(f"FOUND at L{i}: {line.strip()}")
        break
else:
    raise SystemExit("ERR: upsertFromDeal not found")
PY

echo
echo "==> 2) Extract upsertFromDeal() block (best-effort, with line numbers)"
python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/listings/listings.service.ts")
lines = p.read_text(encoding="utf-8").splitlines()

# start line
start = None
for i,l in enumerate(lines):
    if re.search(r"async\s+upsertFromDeal\s*\(", l):
        start = i
        break
if start is None:
    raise SystemExit("ERR: async upsertFromDeal( not found)")

# naive brace matching from first "{"
# find first "{"
brace_i = None
for j in range(start, min(start+50, len(lines))):
    if "{" in lines[j]:
        brace_i = j
        break
if brace_i is None:
    raise SystemExit("ERR: cannot find opening { for function")

depth = 0
end = None
for k in range(brace_i, len(lines)):
    depth += lines[k].count("{")
    depth -= lines[k].count("}")
    if k > brace_i and depth == 0:
        end = k
        break
if end is None:
    raise SystemExit("ERR: cannot find function end by brace matching")

for idx in range(start, end+1):
    print(f"{idx+1:5d} | {lines[idx]}")
PY

echo
echo "==> 3) Within file: prisma listing-related calls"
echo "   - matches: prisma.listing.*, tx.listing.*, .listing.create/.upsert/.update"
rg -n "prisma\.listing|tx\.listing|\.listing\.(create|upsert|update|updateMany|createMany)" "$SVC" || true

echo
echo "✅ ADIM 14C DONE (paste output here)"
