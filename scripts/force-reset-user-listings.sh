#!/usr/bin/env bash
set -euo pipefail

# Repo root'u bul (script nerede olursa olsun)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA="$ROOT/apps/api/prisma/schema.prisma"

echo "ROOT=$ROOT"
echo "SCHEMA=$SCHEMA"

if [ ! -f "$SCHEMA" ]; then
  echo "❌ schema.prisma bulunamadı: $SCHEMA"
  exit 1
fi

cp "$SCHEMA" "$SCHEMA.bak.$(date +%Y%m%d-%H%M%S)"
echo "✅ Backup alındı"

python3 <<'PY'
from pathlib import Path
import re
import os

root = Path(__file__).resolve().parent.parent  # scripts/.. = repo root
p = (root / "apps/api/prisma/schema.prisma").resolve()

txt = p.read_text(encoding="utf-8", errors="replace")

m = re.search(r'(?ms)^\s*model\s+User\s*\{.*?^\s*\}', txt)
if not m:
    raise SystemExit("❌ model User bulunamadı")

block = m.group(0)
lines = block.splitlines(True)

new_lines = []
removed = 0

for line in lines:
    if re.search(r'(?i)\bListing\s*\[\s*\]\b', line):
        removed += 1
        continue
    new_lines.append(line)

insert = "  listings Listing[]\n"

for i in range(len(new_lines)-1, -1, -1):
    if re.match(r'^\s*\}\s*$', new_lines[i]):
        new_lines.insert(i, insert)
        break
else:
    raise SystemExit("❌ model User kapanış '}' bulunamadı")

new_block = "".join(new_lines)
txt2 = txt[:m.start()] + new_block + txt[m.end():]

txt2 = txt2.replace("\ufeff","").replace("\u200b","").replace("\r\n","\n").replace("\r","\n")
txt2 = "\n".join(l.rstrip() for l in txt2.split("\n")) + "\n"

p.write_text(txt2, encoding="utf-8")
print(f"✅ User model Listing[] resetlendi. Kaldırılan satır sayısı: {removed}")
PY

echo
echo "==> prisma format"
cd "$ROOT/apps/api"
pnpm -s prisma format --schema prisma/schema.prisma
echo "✅ prisma format OK"
