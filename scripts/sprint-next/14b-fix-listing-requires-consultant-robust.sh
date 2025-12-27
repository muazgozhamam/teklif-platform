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

# 0) Import'larda ConflictException / NotFoundException yoksa ekle
# '@nestjs/common' importunu yakala
imp = re.search(r"import\s*\{\s*([^}]+)\s*\}\s*from\s*'@nestjs/common';", txt)
if not imp:
    raise SystemExit("ERR: cannot find import { ... } from '@nestjs/common'; in listings.service.ts")

names = [x.strip() for x in imp.group(1).split(",") if x.strip()]
need = []
for n in ["ConflictException", "NotFoundException"]:
    if n not in names:
        need.append(n)
if need:
    new_names = names + need
    new_imp = "import { " + ", ".join(new_names) + " } from '@nestjs/common';"
    txt = txt[:imp.start()] + new_imp + txt[imp.end():]

# 1) upsertFromDeal fonksiyon bloğunu bul
m_fn = re.search(r"async\s+upsertFromDeal\s*\([\s\S]*?\)\s*\{([\s\S]*?)\n\}", txt)
if not m_fn:
    raise SystemExit("ERR: cannot locate upsertFromDeal(...) function block")

fn_body = m_fn.group(1)

# 2) deal fetch satırını bul: const <dealVar> = await this.prisma.deal.findUnique({ ... });
m_deal = re.search(r"(const\s+(\w+)\s*=\s*await\s+this\.prisma\.deal\.findUnique\([\s\S]*?\);\s*)", fn_body)
if not m_deal:
    raise SystemExit("ERR: cannot find `await this.prisma.deal.findUnique(...);` inside upsertFromDeal")

deal_stmt = m_deal.group(1)
deal_var = m_deal.group(2)

# 3) Guard blokları zaten var mı kontrol et; yoksa deal fetch'in hemen altına ekle
guard_nf = f"if (!{deal_var}) throw new NotFoundException('Deal not found');"
guard_cf = f"if (!{deal_var}.consultantId) throw new ConflictException('Deal is not assigned to a consultant yet');"

injected = ""
if guard_nf not in fn_body:
    injected += f"\n    {guard_nf}\n"
if guard_cf not in fn_body:
    injected += f"    {guard_cf}\n"

if injected:
    # deal fetch statement sonuna ekle
    fn_body2 = fn_body.replace(deal_stmt, deal_stmt + injected, 1)
else:
    fn_body2 = fn_body

# 4) listing.create data içine consultant connect ekle
# upsertFromDeal içindeki ilk listing.create(...) hedeflensin
m_create = re.search(r"(this\.prisma\.listing\.create\(\s*\{\s*data\s*:\s*\{\s*)([\s\S]*?)(\s*\}\s*\}\s*\))", fn_body2)
if not m_create:
    raise SystemExit("ERR: cannot find prisma.listing.create({ data: { ... } }) inside upsertFromDeal")

pre, data_inner, post = m_create.group(1), m_create.group(2), m_create.group(3)

if re.search(r"\bconsultant\s*:", data_inner):
    # zaten var
    new_data_inner = data_inner
else:
    new_data_inner = data_inner.rstrip()
    if new_data_inner and not new_data_inner.rstrip().endswith(","):
        new_data_inner += ","
    new_data_inner += f"\n          consultant: {{ connect: {{ id: {deal_var}.consultantId }} }},\n"

fn_body3 = fn_body2[:m_create.start()] + pre + new_data_inner + post + fn_body2[m_create.end():]

# 5) fonksiyon gövdesini dosyada değiştir
txt2 = txt[:m_fn.start(1)] + fn_body3 + txt[m_fn.end(1):]
p.write_text(txt2, encoding="utf-8")
print("✅ Robust patch applied: NotFound+Conflict guards + consultant connect")
PY

echo
echo "==> Build"
cd apps/api
pnpm -s build

echo
echo "✅ ADIM 14B TAMAM"
