#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_DIR="$ROOT/apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"

echo "ROOT=$ROOT"
echo "SCHEMA=$SCHEMA"

test -f "$SCHEMA" || { echo "❌ schema yok"; exit 1; }

ts="$(date +%Y%m%d-%H%M%S)"
cp "$SCHEMA" "$SCHEMA.bak.$ts"
echo "✅ Backup: $SCHEMA.bak.$ts"

python3 - <<'PY'
import re
from pathlib import Path
import os

p = Path(os.environ["SCHEMA"])
txt = p.read_text(encoding="utf-8")

m = re.search(r"(model\s+User\s*\{)(.*?)(\n\})", txt, flags=re.S)
if not m:
    raise SystemExit("❌ model User bulunamadı")

block = m.group(0)

# Zaten ekliyse çık
if re.search(r"\n\s*listings\s+Listing\[\]\b", block):
    print("ℹ️ User.listings zaten var (no-op)")
    raise SystemExit(0)

# consultantDeals satırının altına eklemeyi dene, yoksa offers altına ekle
insert_line = "\n  listings        Listing[]\n"

if "consultantDeals" in block:
    block2 = re.sub(r"(\n\s*consultantDeals\s+Deal\[\][^\n]*\n)", r"\1" + insert_line, block, count=1)
elif "offers" in block:
    block2 = re.sub(r"(\n\s*offers\s+Offer\[\][^\n]*\n)", r"\1" + insert_line, block, count=1)
else:
    block2 = block.replace("\n}", insert_line + "\n}")

if block2 == block:
    raise SystemExit("❌ User model içine insert edemedim (pattern mismatch)")

txt = txt.replace(block, block2)
p.write_text(txt, encoding="utf-8")
print("✅ Added User.listings: Listing[]")
PY

echo "==> prisma format + generate (apps/api)"
cd "$API_DIR"
pnpm -s prisma format --schema prisma/schema.prisma
pnpm -s prisma generate --schema prisma/schema.prisma
echo "✅ Prisma generate OK"

echo
echo "DONE."
