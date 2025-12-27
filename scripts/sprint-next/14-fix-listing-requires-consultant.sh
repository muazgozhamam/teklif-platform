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

# 1) upsertFromDeal içinde deal fetch/findUnique kısmını consultantId include edecek şekilde garanti altına al.
# Basit yaklaşım: deal'ı aldığımız yerde select/include yoksa eklemeye çalış.
# "const deal" satırını yakalayalım.
m = re.search(r"const\s+(\w+)\s*=\s*await\s+this\.prisma\.deal\.findUnique\(\s*\{([\s\S]*?)\}\s*\)\s*;", txt)
if not m:
    raise SystemExit("ERR: cannot find prisma.deal.findUnique(...) in listings.service.ts (upsertFromDeal)")

deal_var = m.group(1)
deal_args = m.group(2)

# consultantId alanı zaten geliyorsa dokunma
if "consultantId" not in deal_args and "select" not in deal_args and "include" not in deal_args:
    # hiçbir select/include yoksa prisma default tüm scalar'ları getirir; consultantId scalar zaten gelir.
    pass

# 2) consultantId guard ekle (upsertFromDeal içinde deal null kontrolünden sonra)
# deal null check'ten sonra ekleyeceğiz.
anchor = re.search(rf"if\s*\(\s*!\s*{deal_var}\s*\)\s*\{{[\s\S]*?\}}\s*", txt)
if not anchor:
    raise SystemExit("ERR: cannot find deal null-check block")

insert_pos = anchor.end()

guard_block = f"""
    // Listing create için consultant zorunlu (Prisma relation). Deal assign edilmemişse listing üretmeyelim.
    if (!{deal_var}.consultantId) {{
      const err: any = new Error('Deal is not assigned to a consultant yet');
      err.status = 409;
      throw err;
    }}

"""

if "Deal is not assigned to a consultant yet" not in txt:
    txt = txt[:insert_pos] + guard_block + txt[insert_pos:]

# 3) listing create data içine consultant connect ekle (consultant: { connect: { id: <dealVar>.consultantId } })
# listing.create({ data: { ... } }) içindeki data objesine consultant ekleyeceğiz.
create_m = re.search(r"this\.prisma\.listing\.create\(\s*\{\s*data\s*:\s*\{\s*([\s\S]*?)\s*\}\s*\}\s*\)", txt)
if not create_m:
    raise SystemExit("ERR: cannot find prisma.listing.create({ data: { ... } })")

data_inner = create_m.group(1)

if re.search(r"\bconsultant\s*:", data_inner):
    # zaten ekliyse dokunma
    pass
else:
    # sona consultant connect ekle
    data_inner2 = data_inner.rstrip()
    if data_inner2 and not data_inner2.rstrip().endswith(","):
        data_inner2 += ","
    data_inner2 += f"\n          consultant: {{ connect: {{ id: {deal_var}.consultantId }} }},\n"
    txt = txt[:create_m.start(1)] + data_inner2 + txt[create_m.end(1):]

p.write_text(txt, encoding="utf-8")
print("✅ upsertFromDeal patched: requires consultant + connect on create")
PY

echo
echo "==> Build"
cd apps/api
pnpm -s build

echo
echo "✅ ADIM 14 TAMAM"
echo "Sonraki: API restart + smoke tekrar."
