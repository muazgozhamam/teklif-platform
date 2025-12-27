#!/usr/bin/env bash
set -euo pipefail

# RUN FROM repo root
if [ ! -d "apps/api" ]; then
  echo "HATA: Bu script repo kökünde çalışmalı (teklif-platform)."
  exit 1
fi

API_DIR="apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"

if [ ! -f "$SCHEMA" ]; then
  echo "HATA: schema.prisma bulunamadı: $SCHEMA"
  exit 1
fi

backup="$SCHEMA.bak.$(date +%Y%m%d_%H%M%S)"
cp "$SCHEMA" "$backup"
echo "==> Backup: $backup"

python3 - <<'PY'
import re, pathlib

p = pathlib.Path("apps/api/prisma/schema.prisma")
txt = p.read_text(encoding="utf-8")

# 1) Offer modelindeki consultant relation'a isim verelim (ileride çakışma olmasın)
# consultant    User @relation(name: "UserOffers", ...)
txt = re.sub(
    r"^\s*consultant\s+User\s+@relation\(\s*fields:\s*\[consultantId\]\s*,\s*references:\s*\[id\]\s*,\s*onDelete:\s*Restrict\s*\)\s*$",
    "  consultant    User        @relation(name: \"UserOffers\", fields: [consultantId], references: [id], onDelete: Restrict)",
    txt,
    flags=re.M
)

# 2) User modeline opposite field ekle (offers Offer[] @relation("UserOffers"))
m = re.search(r"(^model\s+User\s*\{.*?^\})\s*$", txt, flags=re.M|re.S)
if not m:
    raise SystemExit("User modeli bulunamadı. schema.prisma içinde model User yok.")

block = m.group(1)
if re.search(r'^\s*offers\s+Offer\[\]', block, flags=re.M):
    # zaten var; sadece relation adı yoksa eklemeyi deneyelim
    block2 = re.sub(
        r'^\s*offers\s+Offer\[\]\s*$',
        '  offers    Offer[]   @relation("UserOffers")',
        block,
        flags=re.M
    )
    block = block2
else:
    lines = block.splitlines()
    # kapanış } öncesine ekle
    insert_idx = len(lines) - 1
    lines.insert(insert_idx, '  offers    Offer[]   @relation("UserOffers")')
    block = "\n".join(lines)

txt = txt[:m.start(1)] + block + txt[m.end(1):]

p.write_text(txt, encoding="utf-8")
print("==> Patched User <-> Offer relation: User.offers added + relation name set.")
PY

echo "==> Running prisma validate/format/migrate..."
cd apps/api
pnpm prisma format
pnpm prisma validate
pnpm prisma migrate dev --name offer_system
pnpm prisma generate
echo "==> DONE"
