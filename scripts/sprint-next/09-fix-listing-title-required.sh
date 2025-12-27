#!/usr/bin/env bash
set -euo pipefail

# ÇALIŞMA KÖKÜ
cd ~/Desktop/teklif-platform

SVC="apps/api/src/listings/listings.service.ts"
test -f "$SVC" || { echo "ERR: missing $SVC"; exit 1; }

echo "==> Patching: $SVC"

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/listings/listings.service.ts")
txt = p.read_text(encoding="utf-8")

# upsertFromDeal içindeki data objesine title ekleyeceğiz.
# Bizim eklediğimiz blokta "const data: any = { ... }" var.
m = re.search(r"const\s+data:\s*any\s*=\s*\{\s*(.*?)\s*\};", txt, flags=re.S)
if not m:
    raise SystemExit("ERR: could not find `const data: any = { ... };` block in upsertFromDeal")

block = m.group(1)

# Zaten title varsa dokunma
if re.search(r"\btitle\s*:", block):
    print("OK: title already present, nothing to do")
else:
    # title satırını ekle
    # city/district/type/rooms null olabilir, o yüzden fallback string üretelim
    title_line = "      title: [data.city, data.district, data.type, data.rooms].filter(Boolean).join(' - ') || 'İlan Taslağı',\n"
    # block içine en sona ekleyelim
    new_block = block.rstrip() + "\n" + title_line.rstrip("\n")
    txt = txt[:m.start(1)] + new_block + txt[m.end(1):]
    p.write_text(txt, encoding="utf-8")
    print("✅ Injected title into listing create/update data")
PY

echo
echo "==> Build"
cd apps/api
pnpm -s build

echo
echo "✅ ADIM 9 TAMAM"
echo "Sonraki: smoke script'i tekrar çalıştıracağız."
