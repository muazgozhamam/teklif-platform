#!/usr/bin/env bash
set -euo pipefail

# ÇALIŞMA KÖKÜ
cd ~/Desktop/teklif-platform

SVC="apps/api/src/listings/listings.service.ts"
test -f "$SVC" || { echo "ERR: missing $SVC"; exit 1; }

echo "==> Fixing: $SVC"

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/listings/listings.service.ts")
txt = p.read_text(encoding="utf-8")

# 1) Hatalı data.* referanslı title satırını kaldır (varsa)
txt2 = re.sub(
    r"\n\s*title:\s*\[data\.city,\s*data\.district,\s*data\.type,\s*data\.rooms\]\.filter\(Boolean\)\.join\(' - '\)\s*\|\|\s*'İlan Taslağı',?\s*",
    "\n",
    txt
)

# 2) const data: any = { ... } bloğunu yakala ve içine deal.* ile title ekle
m = re.search(r"(const\s+data:\s*any\s*=\s*\{\s*)(.*?)(\s*\};)", txt2, flags=re.S)
if not m:
    raise SystemExit("ERR: could not find `const data: any = { ... };` block")

head, body, tail = m.group(1), m.group(2), m.group(3)

# Eğer zaten title: var ama farklıysa, onu deal.* ile değiştir
if re.search(r"\btitle\s*:", body):
    body = re.sub(
        r"\btitle\s*:\s*[^,\n}]+,?",
        "title: [deal.city, deal.district, deal.type, deal.rooms].filter(Boolean).join(' - ') || 'İlan Taslağı',",
        body
    )
else:
    # title yoksa sona ekle (virgül düzeni için basit yaklaşım)
    body = body.rstrip()
    if body and not body.rstrip().endswith(","):
        body = body.rstrip() + ","
    body = body + "\n      title: [deal.city, deal.district, deal.type, deal.rooms].filter(Boolean).join(' - ') || 'İlan Taslağı',\n"

new_block = head + body + tail
txt3 = txt2[:m.start()] + new_block + txt2[m.end():]

p.write_text(txt3, encoding="utf-8")
print("✅ title fixed to be deal-based")
PY

echo
echo "==> Build"
cd apps/api
pnpm -s build

echo
echo "✅ ADIM 10 TAMAM"
