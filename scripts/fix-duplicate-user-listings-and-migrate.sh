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

p = Path(os.environ["SCHEMA"])
txt = p.read_text(encoding="utf-8")

m = re.search(r"(model\s+User\s*\{)([\s\S]*?)(\n\})", txt)
if not m:
    raise SystemExit("❌ model User bloğu bulunamadı.")

head, body, tail = m.group(1), m.group(2), m.group(3)
lines = body.splitlines(True)

kept = False
out = []
removed = 0

# "listings Listing[]" satırlarını dedup et (ilkini bırak)
pat = re.compile(r"^\s*listings\s+Listing\[\]\b.*$", re.M)

for line in lines:
    if pat.match(line):
        if not kept:
            kept = True
            out.append(line)
        else:
            removed += 1
            # drop duplicate
            continue
    else:
        out.append(line)

if removed == 0:
    print("ℹ️ Duplicate listings yok (değişiklik yapılmadı).")
else:
    print(f"✅ Removed duplicate listings lines: {removed}")

new_user = head + "".join(out) + tail
txt2 = txt[:m.start()] + new_user + txt[m.end():]
p.write_text(txt2, encoding="utf-8")
PY

echo "==> prisma format"
cd "$API_DIR"
pnpm -s prisma format --schema prisma/schema.prisma

echo "==> prisma migrate dev"
pnpm -s prisma migrate dev --schema prisma/schema.prisma --name sync_after_reset_2

echo "==> prisma generate"
pnpm -s prisma generate --schema prisma/schema.prisma

echo "==> build"
pnpm -s build

echo "✅ DONE: dedup User.listings + migrate + generate + build"
