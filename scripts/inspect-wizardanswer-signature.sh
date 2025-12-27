#!/usr/bin/env bash
set -euo pipefail
FILE="$(pwd)/apps/api/src/leads/leads.service.ts"

python3 - <<'PY' "$FILE"
import re, sys
txt=open(sys.argv[1],encoding="utf-8").read()

# multiline-safe: capture until the matching ')'
m=re.search(r"\basync\s+wizardAnswer\s*\(", txt)
if not m:
  print("NOT_FOUND")
  raise SystemExit(0)

i=m.end()
depth=1
while i < len(txt) and depth>0:
  if txt[i] == "(":
    depth += 1
  elif txt[i] == ")":
    depth -= 1
  i += 1

sig = txt[m.start():i]
print(sig)
PY
