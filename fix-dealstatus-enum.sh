#!/usr/bin/env bash
set -euo pipefail

FILE="apps/api/src/deals/deals.service.ts"

echo "==> Backup"
cp "$FILE" "$FILE.bak.$(date +%Y%m%d-%H%M%S)"

python3 - <<'PY'
import pathlib, re

path = pathlib.Path("apps/api/src/deals/deals.service.ts")
txt = path.read_text(encoding="utf-8")

# READY -> OPEN
txt = re.sub(r"'READY'", "'OPEN'", txt)

# advanceDeal: status: event -> status: event as any
txt = re.sub(
    r"data:\s*\{\s*status:\s*event\s*\}",
    "data: { status: event as any }",
    txt
)

path.write_text(txt, encoding="utf-8")
print("✅ DealStatus enum fixed (READY → OPEN)")
PY

echo "==> Build"
cd apps/api
pnpm -s build
