#!/usr/bin/env bash
set -euo pipefail

# ÇALIŞMA KÖKÜ
cd ~/Desktop/teklif-platform

SCHEMA="apps/api/prisma/schema.prisma"

echo "==> ROOT: $(pwd)"
echo "==> Checking: $SCHEMA"
test -f "$SCHEMA" || { echo "ERR: schema not found"; exit 1; }

echo
echo "==> 1) Listing model var mı?"
if rg -n "model\s+Listing\s*\{" "$SCHEMA" >/dev/null; then
  echo "OK: Listing model FOUND"
  rg -n "model\s+Listing\s*\{" -n "$SCHEMA" || true
else
  echo "NO: Listing model NOT found"
fi

echo
echo "==> 2) Deal içinde listing ilişkisi var mı?"
if rg -n "model\s+Deal\s*\{" "$SCHEMA" >/dev/null; then
  # Deal bloğundan listingId / listing satırlarını kaba yakala
  echo "Deal listingId/listing lines:"
  python3 - <<'PY'
from pathlib import Path
import re

txt = Path("apps/api/prisma/schema.prisma").read_text(encoding="utf-8")
m = re.search(r"model\s+Deal\s*\{(.*?)\n\}", txt, flags=re.S)
if not m:
    print("ERR: Deal model block not found")
    raise SystemExit(1)
block = m.group(1)
lines = [ln for ln in block.splitlines() if ("listing" in ln or "Listing" in ln)]
if lines:
    for ln in lines:
        print(ln)
else:
    print("(none)")
PY
else
  echo "ERR: Deal model NOT found"
fi

echo
echo "==> 3) Prisma migrations listing ile ilgili var mı?"
ls -1 apps/api/prisma/migrations 2>/dev/null | tail -n 20 || true
echo
echo "==> Migrations içinde 'listing' geçenler:"
rg -n "listing" apps/api/prisma/migrations -S || true

echo
echo "==> 4) API src içinde listing endpoints var mı?"
echo "Files:"
ls -la apps/api/src/listings 2>/dev/null || echo "(no listings dir)"
echo
echo "Routes (controller içinde /deals/:dealId/listing var mı?)"
rg -n "/deals/:dealId/listing" apps/api/src -S || true

echo
echo "✅ ADIM 3 CHECK DONE"
