#!/usr/bin/env bash
set -euo pipefail
ROOT="${ROOT:-$(pwd)}"
CTRL="$ROOT/apps/api/src/leads/leads.controller.ts"

if [[ ! -f "$CTRL" ]]; then
  echo "❌ Controller not found: $CTRL"
  exit 1
fi

python3 - "$CTRL" <<'PY'
import sys
from pathlib import Path

p = Path(sys.argv[1])
lines = p.read_text(encoding="utf-8").splitlines()

# find line with wizard/answer decorator
idx = None
for i, ln in enumerate(lines):
    if "wizard/answer" in ln and "@Post" in ln:
        idx = i
        break

if idx is None:
    print("❌ Could not find @Post(...wizard/answer...) line.")
    raise SystemExit(2)

start = max(0, idx-25)
end = min(len(lines), idx+120)

print(f"==> File: {p}")
print(f"==> @Post wizard/answer at line {idx+1}")
print("==> Context (line numbers):")
for j in range(start, end):
    print(f"{j+1:4d} | {lines[j]}")

print("\n==> Quick hints:")
print("- Look for the FIRST method name after the decorator block.")
print("- Then inside that method, look for service call e.g. this.leadsService.X(...).")
PY
