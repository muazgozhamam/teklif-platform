#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"

echo "==> 0) Preconditions"
[ -d "$API_DIR/src" ] || { echo "ERROR: apps/api/src yok"; exit 1; }

echo "==> 1) Write deals.module.ts + deals.service.ts"
mkdir -p "$API_DIR/src/deals"

cat > "$API_DIR/src/deals/deals.module.ts" <<'TS'
import { Module } from '@nestjs/common';
import { DealsController } from './deals.controller';
import { DealsService } from './deals.service';

@Module({
  controllers: [DealsController],
  providers: [DealsService],
  exports: [DealsService],
})
export class DealsModule {}
TS

cat > "$API_DIR/src/deals/deals.service.ts" <<'TS'
import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class DealsService {
  constructor(private prisma: PrismaService) {}

  async getByLeadId(leadId: string) {
    const deal =
      (await (this.prisma as any).deal.findUnique?.({ where: { leadId } })) ??
      (await (this.prisma as any).deal.findFirst({ where: { leadId } }));

    if (!deal) throw new NotFoundException('Deal not found');
    return deal;
  }

  async ensureForLead(leadId: string) {
    const existing =
      (await (this.prisma as any).deal.findUnique?.({ where: { leadId } })) ??
      (await (this.prisma as any).deal.findFirst({ where: { leadId } }));

    if (existing) return existing;

    try {
      return await (this.prisma as any).deal.create({ data: { leadId } });
    } catch {
      return await (this.prisma as any).deal.create({ data: { leadId, status: 'OPEN' } });
    }
  }
}
TS

echo "==> 2) Ensure AppModule imports DealsModule"
python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/app.module.ts")
s = p.read_text(encoding="utf-8")

if "DealsModule" not in s:
    # import ekle
    s = s.replace(
        "import { LeadsModule } from './leads/leads.module';",
        "import { LeadsModule } from './leads/leads.module';\nimport { DealsModule } from './deals/deals.module';"
    )

# imports array'a ekle
if re.search(r"imports\s*:\s*\[[^\]]*\bDealsModule\b", s, re.S) is None:
    s = s.replace("LeadsModule,", "LeadsModule,\n    DealsModule,")

p.write_text(s, encoding="utf-8")
print("OK: AppModule patched")
PY

echo "==> 3) Ensure LeadsModule imports DealsModule (DI için)"
python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/leads/leads.module.ts")
s = p.read_text(encoding="utf-8")

if "DealsModule" not in s:
    s = "import { DealsModule } from '../deals/deals.module';\n" + s

# Module decorator içine imports: [DealsModule] ekle
if re.search(r"@Module\(\s*\{", s) and "imports:" not in s:
    s = s.replace("@Module({", "@Module({\n  imports: [DealsModule],")
elif "imports:" in s and "DealsModule" not in s:
    s = re.sub(r"imports\s*:\s*\[", "imports: [DealsModule, ", s, count=1)

p.write_text(s, encoding="utf-8")
print("OK: LeadsModule patched")
PY

echo "==> 4) Patch LeadsService to use DealsService on completion"
python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/leads/leads.service.ts")
s = p.read_text(encoding="utf-8")

# import ekle
if "DealsService" not in s:
    s = s.replace(
        "import { PrismaService } from '../prisma/prisma.service';",
        "import { PrismaService } from '../prisma/prisma.service';\nimport { DealsService } from '../deals/deals.service';"
    )

# constructor patch (prisma only -> prisma + dealsService)
s = re.sub(
    r"constructor\(\s*private prisma:\s*PrismaService\s*\)\s*\{\}",
    "constructor(private prisma: PrismaService, private dealsService: DealsService) {}",
    s
)

# done:true branch içine ensureForLead ekle
# pattern: if (!next) { ... return { done: true }; }
if "ensureForLead" not in s:
    s = re.sub(
        r"(if\s*\(!next\)\s*\{\s*[\s\S]*?return\s*\{\s*done:\s*true\s*\}\s*;?\s*\})",
        lambda m: re.sub(
            r"return\s*\{\s*done:\s*true\s*\}\s*;?",
            "await this.dealsService.ensureForLead(id);\n      return { done: true };",
            m.group(1)
        ),
        s,
        count=1
    )

p.write_text(s, encoding="utf-8")
print("OK: LeadsService patched")
PY

echo "==> 5) Prisma generate + build"
cd "$API_DIR"
pnpm -s prisma generate --schema prisma/schema.prisma
pnpm -s build

echo
echo "==> DONE"
echo "Şimdi dev server restart şart:"
echo "  cd apps/api && pnpm start:dev"
echo "Sonra test:"
echo "  curl -i http://localhost:3001/health"
echo "  curl -i http://localhost:3001/docs"
echo "  curl -i http://localhost:3001/deals/by-lead/<LEAD_ID>"
