#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_DIR="$ROOT/apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"
echo "SCHEMA=$SCHEMA"
test -f "$SCHEMA" || { echo "❌ schema.prisma yok"; exit 1; }

ts="$(date +%Y%m%d-%H%M%S)"
cp "$SCHEMA" "$SCHEMA.bak.$ts"
echo "✅ Backup: $SCHEMA.bak.$ts"

python3 - <<'PY'
from pathlib import Path
import re, os

schema = Path(os.environ["SCHEMA"])
txt = schema.read_text(encoding="utf-8")

# Listing modeli varsa, consultant relation'ına name ver + User tarafına opposite ekle.
has_listing = re.search(r"^\s*model\s+Listing\s*\{", txt, flags=re.M) is not None

if has_listing:
    # 1) Listing.consultant relation'ına name ekle (yoksa)
    # consultant   User @relation(fields:[consultantId], references:[id], ...)
    # -> consultant User @relation(name:"ListingConsultant", fields:[consultantId], references:[id], ...)
    def add_relation_name(m):
        line = m.group(0)
        if 'name:' in line or 'name =' in line:
            return line
        # @relation( ... ) içine name ekle
        line = re.sub(r"@relation\s*\(\s*", '@relation(name: "ListingConsultant", ', line)
        return line

    txt2 = re.sub(
        r"^\s*consultant\s+User\s+@relation\([^\)]*fields:\s*\[consultantId\][^\)]*\)\s*$",
        add_relation_name,
        txt,
        flags=re.M
    )
    txt = txt2

    # 2) User modeline opposite relation ekle (yoksa)
    # model User { ... }
    m = re.search(r"model\s+User\s*\{([\s\S]*?)\n\}", txt)
    if m:
        block = m.group(0)
        if re.search(r"^\s*listings\s+Listing\[\]", block, flags=re.M) is None:
            # kapanıştan önce ekle
            insert = "\n  listings         Listing[] @relation(\"ListingConsultant\")\n"
            block2 = re.sub(r"\n\}$", insert + "\n}", block)
            txt = txt.replace(block, block2)

# Son yazım
schema.write_text(txt, encoding="utf-8")
print("✅ schema.prisma patched (Listing consultant relation + User.listings if needed)")
PY

echo "==> prisma format"
cd "$API_DIR"
pnpm -s prisma format --schema prisma/schema.prisma

echo "==> prisma migrate dev (new migration after reset)"
pnpm -s prisma migrate dev --schema prisma/schema.prisma --name sync_after_reset

echo "==> prisma generate"
pnpm -s prisma generate --schema prisma/schema.prisma

echo "==> build"
pnpm -s build

echo "✅ DONE: schema synced + migrate applied + build OK"
