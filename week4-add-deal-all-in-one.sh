#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
SCHEMA="apps/api/prisma/schema.prisma"
APP_MODULE="apps/api/src/app.module.ts"
LEADS_SERVICE="apps/api/src/leads/leads.service.ts"

echo "==> 0) Preconditions check"
[ -f "$SCHEMA" ] || { echo "ERROR: $SCHEMA not found"; exit 1; }
[ -f "$APP_MODULE" ] || { echo "ERROR: $APP_MODULE not found"; exit 1; }
[ -f "$LEADS_SERVICE" ] || { echo "ERROR: $LEADS_SERVICE not found"; exit 1; }

echo "==> 1) Patch Prisma schema: add DealStatus enum + Deal model + Lead.deal relation"
python3 - <<'PY'
from pathlib import Path
import re, sys

schema_path = Path("apps/api/prisma/schema.prisma")
s = schema_path.read_text(encoding="utf-8")

# 1) Add DealStatus enum if missing
if "enum DealStatus" not in s:
    # place after LeadStatus enum if exists, else after Role enum, else append
    insert_after = None
    m = re.search(r'enum\s+LeadStatus\s*\{[^}]*\}\s*', s, flags=re.S)
    if m:
        insert_after = m.end()
    else:
        m = re.search(r'enum\s+Role\s*\{[^}]*\}\s*', s, flags=re.S)
        if m:
            insert_after = m.end()

    enum_block = "\n\nenum DealStatus {\n  OPEN\n  WON\n  LOST\n}\n"
    if insert_after:
        s = s[:insert_after] + enum_block + s[insert_after:]
    else:
        s = s.rstrip() + enum_block + "\n"

# 2) Add Deal model if missing
if re.search(r'\bmodel\s+Deal\s*\{', s) is None:
    deal_model = """
model Deal {
  id        String     @id @default(cuid())
  createdAt DateTime   @default(now())
  updatedAt DateTime   @updatedAt

  status    DealStatus @default(OPEN)

  // LeadAnswer snapshot (LeadAnswer key’lerinden dolacak)
  city      String?
  district  String?
  type      String?   // kiralık/satılık
  rooms     String?

  leadId    String     @unique
  lead      Lead       @relation(fields: [leadId], references: [id], onDelete: Cascade)

  @@index([status])
}
"""
    s = s.rstrip() + "\n\n" + deal_model.strip() + "\n"

# 3) Add Lead.deal relation if missing
lead_model = re.search(r'(model\s+Lead\s*\{)(.*?)(\n\})', s, flags=re.S)
if not lead_model:
    print("ERROR: Lead model not found in schema.prisma", file=sys.stderr)
    sys.exit(1)

lead_block = lead_model.group(0)
if re.search(r'^\s*deal\s+Deal\?\s*$', lead_block, flags=re.M) is None:
    # insert before closing brace of Lead model, preferably after offers
    # find line with "offers  Offer[]" and insert after, else before closing
    lines = lead_block.splitlines()
    inserted = False
    for i, line in enumerate(lines):
        if re.search(r'^\s*offers\s+Offer\[\]', line):
            # insert next line
            lines.insert(i+1, "  deal    Deal?")
            inserted = True
            break
    if not inserted:
        # insert before last line "}"
        for i in range(len(lines)-1, -1, -1):
            if lines[i].strip() == "}":
                lines.insert(i, "  deal    Deal?")
                inserted = True
                break
    new_lead_block = "\n".join(lines)
    s = s.replace(lead_block, new_lead_block)

schema_path.write_text(s, encoding="utf-8")
print("==> schema.prisma patched OK")
PY

echo "==> 2) Run prisma migration (add_deal)"
pnpm -s prisma migrate dev -n add_deal --schema "$SCHEMA"

echo "==> 3) Create deals module/service/controller"
mkdir -p apps/api/src/deals

cat > apps/api/src/deals/deals.module.ts <<'TS'
import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { DealsController } from './deals.controller';
import { DealsService } from './deals.service';

@Module({
  imports: [PrismaModule],
  controllers: [DealsController],
  providers: [DealsService],
  exports: [DealsService],
})
export class DealsModule {}
TS

cat > apps/api/src/deals/deals.service.ts <<'TS'
import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class DealsService {
  constructor(private prisma: PrismaService) {}

  async getById(id: string) {
    const deal = await this.prisma.deal.findUnique({
      where: { id },
      include: {
        lead: {
          include: {
            answers: { orderBy: { createdAt: 'asc' } },
            offers: true,
          },
        },
      },
    });
    if (!deal) throw new NotFoundException('Deal not found');
    return deal;
  }

  async getByLeadId(leadId: string) {
    const deal = await this.prisma.deal.findUnique({ where: { leadId } });
    if (!deal) throw new NotFoundException('Deal not found for lead');
    return deal;
  }
}
TS

cat > apps/api/src/deals/deals.controller.ts <<'TS'
import { Controller, Get, Param } from '@nestjs/common';
import { DealsService } from './deals.service';

@Controller('deals')
export class DealsController {
  constructor(private deals: DealsService) {}

  @Get(':id')
  get(@Param('id') id: string) {
    return this.deals.getById(id);
  }

  @Get('by-lead/:leadId')
  getByLead(@Param('leadId') leadId: string) {
    return this.deals.getByLeadId(leadId);
  }
}
TS

echo "==> 4) Patch AppModule to import DealsModule + add to imports[]"
python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/app.module.ts")
s = p.read_text(encoding="utf-8")

# add import if missing
if "from './deals/deals.module'" not in s:
    # insert after LeadsModule import if possible
    m = re.search(r"import\s+\{\s*LeadsModule\s*\}\s+from\s+'\.\/leads\/leads\.module';\s*", s)
    if m:
        ins = m.end()
        s = s[:ins] + "\nimport { DealsModule } from './deals/deals.module';" + s[ins:]
    else:
        # put after last import
        last_import = list(re.finditer(r"^import .*;$", s, flags=re.M))[-1]
        ins = last_import.end()
        s = s[:ins] + "\nimport { DealsModule } from './deals/deals.module';" + s[ins:]

# add DealsModule into imports array if missing
if re.search(r'\bDealsModule\b', s) is None:
    # locate imports: [ ... ]
    m = re.search(r"imports:\s*\[(.*?)\]\s*,", s, flags=re.S)
    if m:
        block = m.group(1)
        # insert before closing bracket
        new_block = block.rstrip() + "\n    DealsModule,"
        s = s[:m.start(1)] + new_block + s[m.end(1):]

p.write_text(s, encoding="utf-8")
print("==> app.module.ts patched OK")
PY

echo "==> 5) Patch LeadsService to create Deal when lead completes"
python3 - <<'PY'
from pathlib import Path
import re, sys

p = Path("apps/api/src/leads/leads.service.ts")
s = p.read_text(encoding="utf-8")

# if already has ensureDealForCompletedLead, skip
if "ensureDealForCompletedLead" in s:
    print("==> leads.service.ts already patched; skipping")
    sys.exit(0)

# Add helper methods inside class, after getLead method (best-effort)
# We'll inject:
# - answerMap()
# - ensureDealForCompletedLead()
# - call ensureDealForCompletedLead(id) when no next question

# 1) Inject helper methods right after getLead method block ends
getLead_match = re.search(r"async\s+getLead\(id:\s*string\)\s*\{.*?\n\s*\}\n", s, flags=re.S)
if not getLead_match:
    print("ERROR: Could not find getLead() method to patch", file=sys.stderr)
    sys.exit(1)

helpers = """
  private answerMap(lead: { answers: Array<{ key: string; answer: string }> }) {
    const m = new Map<string, string>();
    for (const a of lead.answers) m.set(a.key, a.answer);
    return m;
  }

  private async ensureDealForCompletedLead(leadId: string) {
    // idempotent
    const existing = await this.prisma.deal.findUnique({ where: { leadId } });
    if (existing) return existing;

    const lead = await this.getLead(leadId);
    const m = this.answerMap(lead);

    const city = m.get('city') ?? null;
    const district = m.get('district') ?? null;
    const type = m.get('type') ?? null;
    const rooms = m.get('rooms') ?? null;

    return this.prisma.deal.create({
      data: {
        leadId,
        status: 'OPEN',
        city,
        district,
        type,
        rooms,
      },
    });
  }
"""

insert_pos = getLead_match.end()
s = s[:insert_pos] + helpers + s[insert_pos:]

# 2) Add call in nextQuestion when no next question
# Find the "if (!next) { ... return { done: true } }" block and insert before return
pattern = r"(if\s*\(!next\)\s*\{\s*[\s\S]*?)(return\s*\{\s*done:\s*true\s*\};\s*\})"
m = re.search(pattern, s)
if not m:
    # fallback: find "return { done: true }" and inject above first occurrence after "!next"
    m2 = re.search(r"if\s*\(!next\)\s*\{([\s\S]*?)return\s*\{\s*done:\s*true\s*\};", s)
    if not m2:
        print("ERROR: Could not patch nextQuestion() completion block", file=sys.stderr)
        sys.exit(1)
    start = m2.start()
    end = m2.end()
    block = s[start:end]
    block = block.replace("return { done: true };", "await this.ensureDealForCompletedLead(id);\n      return { done: true };")
    s = s[:start] + block + s[end:]
else:
    before = m.group(1)
    after = m.group(2)
    if "ensureDealForCompletedLead" not in before:
        before = before.rstrip() + "\n\n      // COMPLETED -> Deal üret\n      await this.ensureDealForCompletedLead(id);\n\n      "
    s = s[:m.start()] + before + after + s[m.end():]

p.write_text(s, encoding="utf-8")
print("==> leads.service.ts patched OK")
PY

echo "==> 6) DONE"
echo
echo "Next:"
echo "  - API dev serverin açıksa (pnpm start:dev) hot-reload alacaktır."
echo "  - Test:"
echo "      curl -i -X POST http://localhost:3001/leads -H 'Content-Type: application/json' -d '{\"initialText\":\"Konya Sancak 2+1 satılık\"}'"
echo "      LEAD_ID='...'; curl -s http://localhost:3001/leads/\$LEAD_ID/next"
echo "      (soruları cevapla) ... tamamlanınca:"
echo "      curl -i http://localhost:3001/deals/by-lead/\$LEAD_ID"
