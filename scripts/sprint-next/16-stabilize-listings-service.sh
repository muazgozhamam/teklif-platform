#!/usr/bin/env bash
set -euo pipefail

# ÇALIŞMA KÖKÜ (kullanıcı yazmasın)
cd ~/Desktop/teklif-platform

FILE="apps/api/src/listings/listings.service.ts"
test -f "$FILE" || { echo "ERR: missing $FILE"; exit 1; }

echo "==> Stabilizing: $FILE"

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/listings/listings.service.ts")
txt = p.read_text(encoding="utf-8")

def find_all_method_spans(name: str):
    spans = []
    for m in re.finditer(rf"\n\s*async\s+{re.escape(name)}\s*\(", txt):
        brace_open = txt.find("{", m.end())
        if brace_open == -1:
            continue
        i = brace_open
        depth = 0
        in_str = None
        esc = False
        while i < len(txt):
            ch = txt[i]
            if in_str:
                if esc:
                    esc = False
                elif ch == "\\":
                    esc = True
                elif ch == in_str:
                    in_str = None
            else:
                if ch in ("'", '"', "`"):
                    in_str = ch
                elif ch == "{":
                    depth += 1
                elif ch == "}":
                    depth -= 1
                    if depth == 0:
                        spans.append((m.start()+1, i+1))
                        break
            i += 1
    spans.sort()
    return spans

def replace_method(name: str, new_block: str):
    global txt
    spans = find_all_method_spans(name)
    if not spans:
        raise SystemExit(f"ERR: cannot find method: {name}")
    first_start, first_end = spans[0]
    for s,e in reversed(spans[1:]):
        txt = txt[:s] + "\n" + txt[e:]
    txt = txt[:first_start] + "\n" + new_block.rstrip() + "\n" + txt[first_end:]

def ensure_update_has_data_decl():
    global txt
    spans = find_all_method_spans("update")
    if not spans:
        return
    s,e = spans[0]
    block = txt[s:e]
    if re.search(r"\bconst\s+data\s*:\s*any\s*=\s*\{\s*\}\s*;", block):
        return
    brace = block.find("{")
    if brace == -1:
        return
    insert = "\n    const data: any = {};\n"
    block2 = block[:brace+1] + insert + block[brace+1:]
    txt = txt[:s] + block2 + txt[e:]

# Ensure ConflictException import
m = re.search(r"import\s*\{\s*([^}]+)\s*\}\s*from\s*'@nestjs/common';", txt)
if not m:
    raise SystemExit("ERR: cannot find @nestjs/common import")
items = [x.strip() for x in m.group(1).split(",") if x.strip()]
if "ConflictException" not in items:
    items.append("ConflictException")
    new_imp = "import { " + ", ".join(items) + " } from '@nestjs/common';"
    txt = txt[:m.start()] + new_imp + txt[m.end():]

get_by_deal = """  async getByDealId(dealId: string) {
    const deal = await this.prisma.deal.findUnique({ where: { id: dealId } });
    if (!deal) throw new NotFoundException('Deal not found');

    const listingId = (deal as any).listingId as string | null | undefined;
    if (!listingId) return null;

    return this.prisma.listing.findUnique({ where: { id: listingId } });
  }"""

upsert_from_deal = """  async upsertFromDeal(dealId: string) {
    const deal = await this.prisma.deal.findUnique({ where: { id: dealId } });
    if (!deal) throw new NotFoundException('Deal not found');

    if (!(deal as any).consultantId) {
      throw new ConflictException('Deal is not assigned to a consultant yet');
    }

    const _city = (deal as any).city ?? null;
    const _district = (deal as any).district ?? null;
    const _type = (deal as any).type ?? null;
    const _rooms = (deal as any).rooms ?? null;

    const _title =
      [_city, _district, _type, _rooms].filter(Boolean).join(' - ') || 'İlan Taslağı';

    const updateData: any = {
      city: _city,
      district: _district,
      type: _type,
      rooms: _rooms,
      title: _title,
    };

    const createData: any = {
      ...updateData,
      consultant: { connect: { id: (deal as any).consultantId } },
    };

    const listingId = (deal as any).listingId as string | null | undefined;

    if (listingId) {
      return this.prisma.listing.update({
        where: { id: listingId },
        data: updateData,
      });
    }

    const listing = await this.prisma.listing.create({ data: createData });

    await this.prisma.deal.update({
      where: { id: dealId },
      data: { listingId: listing.id },
    });

    return listing;
  }"""

replace_method("getByDealId", get_by_deal)
replace_method("upsertFromDeal", upsert_from_deal)

ensure_update_has_data_decl()

# Safety: still duplicates? remove extras
for name in ("getByDealId", "upsertFromDeal"):
    spans = find_all_method_spans(name)
    if len(spans) > 1:
        for s,e in reversed(spans[1:]):
            txt = txt[:s] + "\n" + txt[e:]

p.write_text(txt, encoding="utf-8")
print("✅ listings.service.ts stabilized (dedupe + rewrite critical methods)")
PY

echo
echo "==> Clean dist + build"
bash scripts/sprint-next/11-fix-api-dist-enotempty-build.sh

echo
echo "✅ ADIM 16 TAMAM"
