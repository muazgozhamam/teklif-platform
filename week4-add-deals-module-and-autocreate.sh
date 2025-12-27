#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="apps/api"
SRC="$API_DIR/src"
DEALS_DIR="$SRC/deals"

echo "==> 0) Preconditions"
test -d "$API_DIR" || { echo "ERR: $API_DIR yok"; exit 1; }
test -d "$SRC" || { echo "ERR: $SRC yok"; exit 1; }
test -f "$API_DIR/prisma/schema.prisma" || { echo "ERR: schema.prisma yok"; exit 1; }

echo "==> 1) Ensure deals folder & files"
mkdir -p "$DEALS_DIR"

cat <<'TS' > "$DEALS_DIR/deals.service.ts"
import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class DealsService {
  constructor(private prisma: PrismaService) {}

  async getByLeadId(leadId: string) {
    const deal = await this.prisma.deal.findUnique({
      where: { leadId },
      include: {
        lead: {
          include: { answers: { orderBy: { createdAt: 'asc' } } },
        },
      },
    });
    if (!deal) throw new NotFoundException('Deal not found for lead');
    return deal;
  }
}
TS

cat <<'TS' > "$DEALS_DIR/deals.controller.ts"
import { Controller, Get, Param } from '@nestjs/common';
import { DealsService } from './deals.service';

@Controller('deals')
export class DealsController {
  constructor(private deals: DealsService) {}

  @Get('by-lead/:leadId')
  getByLead(@Param('leadId') leadId: string) {
    return this.deals.getByLeadId(leadId);
  }
}
TS

cat <<'TS' > "$DEALS_DIR/deals.module.ts"
import { Module } from '@nestjs/common';
import { DealsController } from './deals.controller';
import { DealsService } from './deals.service';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [DealsController],
  providers: [DealsService],
  exports: [DealsService],
})
export class DealsModule {}
TS

echo "==> 2) Wire DealsModule into AppModule"
APP_MODULE="$SRC/app.module.ts"
python3 - <<'PY'
from pathlib import Path
p = Path("apps/api/src/app.module.ts")
s = p.read_text(encoding="utf-8")

if "from './deals/deals.module'" not in s:
    # import ekle
    lines = s.splitlines()
    out=[]
    inserted=False
    for line in lines:
        out.append(line)
        if line.strip() == "import { LeadsModule } from './leads/leads.module';":
            out.append("import { DealsModule } from './deals/deals.module';")
            inserted=True
    if not inserted:
        # fallback: import blok sonuna ekle
        for i,l in enumerate(out):
            pass
    s = "\n".join(out) + "\n"

# imports array'e DealsModule ekle (LeadsModule'den sonra)
if "DealsModule" not in s:
    raise SystemExit("ERR: DealsModule import eklenemedi")

# zaten ekliyse dokunma, değilse ekle
if "DealsModule," not in s:
    s = s.replace("    LeadsModule,\n", "    LeadsModule,\n    DealsModule,\n")

p.write_text(s, encoding="utf-8")
print("OK: AppModule patched")
PY

echo "==> 3) Patch LeadsService: auto-create Deal on COMPLETED"
LEADS_SERVICE="$SRC/leads/leads.service.ts"
python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/leads/leads.service.ts")
s = p.read_text(encoding="utf-8")

# ensureDealForCompletedLead helper ekle (class içinde, en sona yakın)
if "ensureDealForCompletedLead" not in s:
    # class kapanışından hemen önce ekle
    m = re.search(r"\n}\s*$", s)
    if not m:
        raise SystemExit("ERR: class kapanışı bulunamadı")
    helper = r"""
  private async ensureDealForCompletedLead(leadId: string) {
    // Deal zaten varsa tekrar oluşturma
    const existing = await this.prisma.deal.findUnique({ where: { leadId } });
    if (existing) return existing;

    // Lead var mı?
    const lead = await this.prisma.lead.findUnique({ where: { id: leadId } });
    if (!lead) throw new NotFoundException('Lead not found');

    // Basit başlangıç: status NEW, title initialText'ten türet
    const title = (lead.initialText ?? '').slice(0, 120) || 'Yeni Deal';

    return this.prisma.deal.create({
      data: {
        leadId,
        status: 'NEW',
        title,
      },
    });
  }
"""
    s = s[:m.start()] + "\n" + helper + "\n" + s[m.start():]

# nextQuestion içinde done:true olduğunda ensureDealForCompletedLead çağır
# mevcut blok:
# if (!next) { ... return { done: true }; }
# bunun içine deal üretimini sokacağız.
pattern = r"if\s*\(!next\)\s*{\s*([\s\S]*?)return\s*{\s*done:\s*true\s*};\s*}"
m = re.search(pattern, s)
if not m:
    raise SystemExit("ERR: nextQuestion done bloğu bulunamadı")

block = m.group(0)
if "ensureDealForCompletedLead" not in block:
    # return'den hemen önce ekle
    block2 = re.sub(
        r"return\s*{\s*done:\s*true\s*};",
        "await this.ensureDealForCompletedLead(id);\n      return { done: true };",
        block
    )
    s = s[:m.start()] + block2 + s[m.end():]

p.write_text(s, encoding="utf-8")
print("OK: LeadsService patched")
PY

echo "==> 4) Quick compile check (TypeScript build)"
cd "$API_DIR"
pnpm -s build >/dev/null 2>&1 || {
  echo "WARN: build hata verdi. log için tekrar çalıştır:"
  echo "  cd apps/api && pnpm build"
  exit 1
}

echo "==> DONE"
echo
echo "Test:"
echo "  1) Yeni lead:"
echo "     curl -s -X POST http://localhost:3001/leads -H 'Content-Type: application/json' -d '{\"initialText\":\"Konya Sancak 2+1 satılık\"}'"
echo "  2) next -> answer döngüsü ile COMPLETED yap"
echo "  3) Deal kontrol:"
echo "     curl -i http://localhost:3001/deals/by-lead/<LEAD_ID>"
