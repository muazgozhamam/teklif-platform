#!/usr/bin/env bash
set -euo pipefail

# ÇALIŞMA KÖKÜ
cd ~/Desktop/teklif-platform

SVC="apps/api/src/listings/listings.service.ts"
CTL="apps/api/src/listings/listings.controller.ts"

echo "==> ROOT: $(pwd)"
test -f "$SVC" || { echo "ERR: missing $SVC"; exit 1; }
test -f "$CTL" || { echo "ERR: missing $CTL"; exit 1; }

echo
echo "==> 1) listings.service.ts: Deal->Listing helper metodlarını garanti altına al"
python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/listings/listings.service.ts")
txt = p.read_text(encoding="utf-8")

need_notfound = "NotFoundException" in txt
if not need_notfound:
    # Add NotFoundException to existing imports if possible
    txt2 = re.sub(
        r"from\s+'@nestjs/common';",
        "from '@nestjs/common';\n",
        txt,
        count=1
    )
    # Ensure we import it (simple approach: replace first import line)
    txt2 = re.sub(
        r"import\s+\{\s*([^}]+)\s*\}\s+from\s+'@nestjs/common';",
        lambda m: (
            "import { " + (m.group(1).strip() + ", NotFoundException").replace(", ,", ", ").replace("NotFoundException, NotFoundException", "NotFoundException") + " } from '@nestjs/common';"
            if "NotFoundException" not in m.group(1) else m.group(0)
        ),
        txt2,
        count=1
    )
    txt = txt2

has_get = re.search(r"\basync\s+getByDealId\s*\(", txt) is not None
has_upsert = re.search(r"\basync\s+upsertFromDeal\s*\(", txt) is not None

if not has_get or not has_upsert:
    # Insert methods before last closing brace of class
    # Find the last "}" of file (assume class ends at file end)
    insert = ""

    if not has_get:
        insert += """
  async getByDealId(dealId: string) {
    const deal = await this.prisma.deal.findUnique({
      where: { id: dealId },
      include: { listing: true },
    });
    if (!deal) throw new NotFoundException('Deal not found');
    return deal.listing;
  }
""".rstrip() + "\n\n"

    if not has_upsert:
        insert += """
  // Idempotent: Deal üzerinde listingId varsa update eder, yoksa create+link yapar
  async upsertFromDeal(dealId: string) {
    const deal = await this.prisma.deal.findUnique({ where: { id: dealId } });
    if (!deal) throw new NotFoundException('Deal not found');

    // Deal core alanlarından listing draft üret (wizard genişledikçe burası büyüyecek)
    const data: any = {
      city: (deal as any).city ?? null,
      district: (deal as any).district ?? null,
      type: (deal as any).type ?? null,
      rooms: (deal as any).rooms ?? null,
    };

    const listingId = (deal as any).listingId as string | null | undefined;

    if (listingId) {
      return this.prisma.listing.update({
        where: { id: listingId },
        data,
      });
    }

    const listing = await this.prisma.listing.create({ data });
    await this.prisma.deal.update({
      where: { id: dealId },
      data: { listingId: listing.id },
    });
    return listing;
  }
""".rstrip() + "\n"

    # Place insert before final "}\n" of class/file
    # Safer: insert before last occurrence of "\n}"
    idx = txt.rfind("\n}")
    if idx == -1:
        raise SystemExit("ERR: could not locate file closing brace")
    txt = txt[:idx] + "\n" + insert + txt[idx:]

p.write_text(txt, encoding="utf-8")
print("✅ listings.service.ts patched (if needed)")
PY

echo
echo "==> 2) listings.controller.ts: /deals/:dealId/listing GET/POST ekle (varsa dokunma)"
python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/listings/listings.controller.ts")
txt = p.read_text(encoding="utf-8")

# Ensure we have Param, Get, Post imported
def ensure_imports(txt: str) -> str:
    m = re.search(r"import\s+\{\s*([^}]+)\s*\}\s+from\s+'@nestjs/common';", txt)
    if not m:
        return txt
    items = [x.strip() for x in m.group(1).split(",") if x.strip()]
    for need in ["Get", "Post", "Param", "Controller"]:
        if need not in items:
            items.append(need)
    new_line = "import { " + ", ".join(sorted(set(items), key=lambda s: ["Controller","Get","Post","Param"].index(s) if s in ["Controller","Get","Post","Param"] else 99)) + " } from '@nestjs/common';"
    return txt[:m.start()] + new_line + txt[m.end():]

txt = ensure_imports(txt)

# Check if routes already exist
has_route = "/deals/:dealId/listing" in txt

if not has_route:
    # Find class body insert point: before last }
    insert = """
  @Get('/deals/:dealId/listing')
  getByDeal(@Param('dealId') dealId: string) {
    return this.listings.getByDealId(dealId);
  }

  @Post('/deals/:dealId/listing')
  upsertFromDeal(@Param('dealId') dealId: string) {
    return this.listings.upsertFromDeal(dealId);
  }
""".rstrip() + "\n"

    idx = txt.rfind("\n}")
    if idx == -1:
        raise SystemExit("ERR: could not locate controller closing brace")
    txt = txt[:idx] + "\n" + insert + txt[idx:]

p.write_text(txt, encoding="utf-8")
print("✅ listings.controller.ts patched (if needed)")
PY

echo
echo "==> 3) Build"
cd apps/api
pnpm -s build

echo
echo "==> 4) Quick grep verify"
cd ~/Desktop/teklif-platform
rg -n "/deals/:dealId/listing" apps/api/src/listings/listings.controller.ts || true

echo
echo "✅ ADIM 4 TAMAM"
echo "Doğrulama: API dev çalışırken curl ile GET/POST test edeceğiz."
