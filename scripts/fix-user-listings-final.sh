#!/usr/bin/env bash
set -e

API_DIR="$(pwd)/apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"

echo "SCHEMA=$SCHEMA"

cp "$SCHEMA" "$SCHEMA.bak.$(date +%Y%m%d-%H%M%S)"
echo "✅ Backup alındı"

python3 <<'PY'
from pathlib import Path
import re

p = Path("apps/api/prisma/schema.prisma").resolve()
txt = p.read_text(encoding="utf-8", errors="replace")

m = re.search(r'(?ms)^\s*model\s+User\s*\{.*?^\s*\}', txt)
if not m:
    raise SystemExit("❌ model User bulunamadı")

block = m.group(0)
lines = block.splitlines(True)

new = []
seen = False
removed = 0

for line in lines:
    if "Listing[]" in line:
        if not seen:
            seen = True
            new.append(line)
        else:
            removed += 1
    else:
        new.append(line)

txt2 = txt[:m.start()] + "".join(new) + txt[m.end():]

# normalize
txt2 = txt2.replace("\ufeff","").replace("\u200b","").replace("\r\n","\n").replace("\r","\n")
txt2 = "\n".join(l.rstrip() for l in txt2.split("\n")) + "\n"

p.write_text(txt2, encoding="utf-8")

print(f"✅ User model temizlendi. Silinen Listing[] satırı: {removed}")
PY

echo
echo "==> prisma format"
cd "$API_DIR"
pnpm -s prisma format --schema prisma/schema.prisma

echo
echo "==> prisma migrate dev"
pnpm -s prisma migrate dev --schema prisma/schema.prisma --name fix_user_listings || \
  echo "⚠️ migrate dev reset isteyebilir"

echo
echo "==> prisma generate"
pnpm -s prisma generate --schema prisma/schema.prisma

echo
echo "==> build"
pnpm -s build

echo
echo "✅ HER ŞEY TAMAM"
