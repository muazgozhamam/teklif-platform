#!/usr/bin/env bash
set -euo pipefail

# ÇALIŞMA KÖKÜ
cd ~/Desktop/teklif-platform

FILE="apps/api/src/listings/listings.service.ts"
test -f "$FILE" || { echo "ERR: missing $FILE"; exit 1; }

echo "==> Patching: $FILE"

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/listings/listings.service.ts")
txt = p.read_text(encoding="utf-8")

# 1) '@nestjs/common' importuna ConflictException ekli mi? değilse ekle
m = re.search(r"import\s*\{\s*([^}]+)\s*\}\s*from\s*'@nestjs/common';", txt)
if not m:
    raise SystemExit("ERR: cannot find @nestjs/common import")

items = [x.strip() for x in m.group(1).split(",") if x.strip()]
if "ConflictException" not in items:
    items.append("ConflictException")
    new_imp = "import { " + ", ".join(items) + " } from '@nestjs/common';"
    txt = txt[:m.start()] + new_imp + txt[m.end():]

# 2) upsertFromDeal bloğunu yakala (satır bazlı stabilize)
# deal fetch + notfound mevcut; onun altına consultant guard ekle
if "Deal is not assigned to a consultant yet" not in txt:
    # NotFound satırını bul
    anchor = re.search(r"if\s*\(!deal\)\s*throw\s+new\s+NotFoundException\('Deal not found'\);\s*", txt)
    if not anchor:
        raise SystemExit("ERR: cannot find NotFoundException('Deal not found') line in upsertFromDeal")
    insert_pos = anchor.end()
    guard = "\n    if (!(deal as any).consultantId) throw new ConflictException('Deal is not assigned to a consultant yet');\n"
    txt = txt[:insert_pos] + guard + txt[insert_pos:]

# 3) const data: any = { ... } bloğunu create/update ayrımına çevir
# Hedef: upsertFromDeal içindeki ilk "const data: any = {" bloğu
m_data = re.search(r"const\s+data:\s*any\s*=\s*\{\s*([\s\S]*?)\n\s*\};", txt)
if not m_data:
    raise SystemExit("ERR: cannot find `const data: any = { ... };` block")

body = m_data.group(1)

# Zaten createData/updateData varsa tekrar yapma
if "const updateData" in txt and "const createData" in txt:
    # sadece create'da { data } kullanılıyorsa createData'ya çevir
    txt = re.sub(r"listing\.create\(\{\s*data\s*\}\)", "listing.create({ data: createData })", txt)
    txt = re.sub(r"listing\.update\(\{\s*([\s\S]*?)data\s*,", r"listing.update({\1data: updateData,", txt)
else:
    # body içindeki city/district/type/rooms/title kalsın
    update_block = "const updateData: any = {\n" + body + "\n    };"
    create_block = "const createData: any = {\n" + body + "\n      consultant: { connect: { id: (deal as any).consultantId } },\n    };"

    replacement = update_block + "\n\n    " + create_block
    txt = txt[:m_data.start()] + replacement + txt[m_data.end():]

    # update path: data -> updateData
    txt = re.sub(r"return\s+this\.prisma\.listing\.update\(\{\s*([\s\S]*?)\bdata\s*,", r"return this.prisma.listing.update({\1data: updateData,", txt)

    # create path: { data } -> { data: createData }
    txt = re.sub(r"this\.prisma\.listing\.create\(\{\s*data\s*\}\)", "this.prisma.listing.create({ data: createData })", txt)

# 4) Quick sanity: createData içinde consultant connect var mı?
if "consultant: { connect" not in txt:
    raise SystemExit("ERR: consultant connect not injected (unexpected format)")

p.write_text(txt, encoding="utf-8")
print("✅ upsertFromDeal patched: 409 guard + createData/updateData split + consultant connect")
PY

echo
echo "==> Build (clean dist)"
bash scripts/sprint-next/11-fix-api-dist-enotempty-build.sh

echo
echo "✅ ADIM 15 TAMAM"
