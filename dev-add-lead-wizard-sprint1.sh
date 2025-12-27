#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$ROOT_DIR/apps/api"

say() { printf "\n==> %s\n" "$*"; }
die() { echo "❌ $*" >&2; exit 1; }

[ -d "$API_DIR" ] || die "apps/api yok: $API_DIR"

say "1) Patch: Lead Wizard endpointleri + service"
python3 - <<'PY'
from pathlib import Path
import re

api = Path("apps/api")
leads_ctrl = api / "src/leads/leads.controller.ts"
leads_svc  = api / "src/leads/leads.service.ts"
leads_mod  = api / "src/leads/leads.module.ts"
deals_mod  = api / "src/deals/deals.module.ts"

for p in [leads_ctrl, leads_svc]:
    if not p.exists():
        raise SystemExit(f"Missing: {p}")

# -------------------------
# leads.controller.ts patch
# -------------------------
txt = leads_ctrl.read_text(encoding="utf-8")

# Ensure imports: Body/Param already likely exist, but make safe minimal patch
if "wizard/next-question" not in txt:
    # Find controller class start
    m = re.search(r"export\s+class\s+LeadsController\s*{", txt)
    if not m:
        raise SystemExit("LeadsController class not found")

    inject = r"""

  /**
   * Sprint-1: Lead Wizard (tek tek soru)
   * Statelesstir: Deal alanlarına bakıp sıradaki soruyu üretir.
   */
  @Post(':id/wizard/next-question')
  async wizardNextQuestion(@Param('id') id: string) {
    return this.leadsService.wizardNextQuestion(id);
  }

  @Post(':id/wizard/answer')
  async wizardAnswer(@Param('id') id: string, @Body() body: { answer: string }) {
    return this.leadsService.wizardAnswer(id, body?.answer);
  }
"""
    # Insert before last closing brace of class
    # naive: inject right before last "}"
    txt2 = txt.rstrip()
    if not txt2.endswith("}"):
        raise SystemExit("Unexpected leads.controller.ts ending")
    # insert before final }
    txt2 = txt2[:-1] + inject + "\n}\n"
    leads_ctrl.write_text(txt2, encoding="utf-8")

# Ensure decorators imports exist
txt = leads_ctrl.read_text(encoding="utf-8")
# add Body if missing
if "Body" not in txt.split("from '@nestjs/common'")[0] and "Body" not in txt:
    # best-effort: expand existing import line
    txt = re.sub(
        r"from\s+'@nestjs/common';",
        lambda m: m.group(0),
        txt
    )
# More robust: just ensure import line contains Body, Post, Param
txt = re.sub(
    r"import\s*\{\s*([^}]+)\s*\}\s*from\s+'@nestjs/common';",
    lambda m: "import { " + ", ".join(sorted(set([s.strip() for s in (m.group(1).split(",") + ["Body","Param","Post"]) ]), key=str)) + " } from '@nestjs/common';",
    txt,
    count=1
)
leads_ctrl.write_text(txt, encoding="utf-8")

# -------------------------
# leads.service.ts patch
# -------------------------
txt = leads_svc.read_text(encoding="utf-8")

# Ensure imports for PrismaService and DealsService exist
if "DealsService" not in txt:
    # add import line near top
    # heuristic: after existing imports
    lines = txt.splitlines()
    insert_at = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, "import { DealsService } from '../deals/deals.service';")
    txt = "\n".join(lines) + "\n"

# Ensure constructor has deals
# Typical: constructor(private prisma: PrismaService) {}
txt = re.sub(
    r"constructor\s*\(\s*([^)]*)\)",
    lambda m: ("constructor(" + (
        m.group(1).strip() + (", " if m.group(1).strip() and "DealsService" not in m.group(1) else "")
        + ("" if "DealsService" in m.group(1) else "private dealsService: DealsService")
    ) + ")"),
    txt,
    count=1
)

# Add wizard methods if missing
if "wizardNextQuestion" not in txt:
    m = re.search(r"export\s+class\s+LeadsService\s*{", txt)
    if not m:
        raise SystemExit("LeadsService class not found")

    wizard_block = r"""

  /**
   * Sprint-1: Deal alanlarına göre sıradaki soruyu döndürür.
   * Sıra: city -> district -> type -> rooms
   */
  async wizardNextQuestion(leadId: string) {
    const deal = await this.dealsService.ensureForLead(leadId);

    const next =
      !deal.city ? { field: 'city', question: 'Hangi şehir?' } :
      !deal.district ? { field: 'district', question: 'Hangi ilçe?' } :
      !deal.type ? { field: 'type', question: 'Emlak türü nedir? (Satılık/Kiralık/Dükkan/Arsa vb.)' } :
      !deal.rooms ? { field: 'rooms', question: 'Kaç oda? (örn: 2+1, 3+1)' } :
      null;

    if (!next) {
      return { done: true, dealId: deal.id };
    }

    return { done: false, dealId: deal.id, ...next };
  }

  /**
   * Sprint-1: answer alır, sıradaki boş alana yazar.
   * Not: stateless; "sıradaki" alanı mevcut deal'den hesaplar.
   */
  async wizardAnswer(leadId: string, answer?: string) {
    if (!answer || !String(answer).trim()) {
      return { ok: false, message: 'answer boş olamaz' };
    }

    const deal = await this.dealsService.ensureForLead(leadId);

    const field =
      !deal.city ? 'city' :
      !deal.district ? 'district' :
      !deal.type ? 'type' :
      !deal.rooms ? 'rooms' :
      null;

    if (!field) {
      return { ok: true, done: true, dealId: deal.id };
    }

    const value = String(answer).trim();

    const data: any = {};
    data[field] = value;

    const updated = await this.dealsService['prisma'].deal.update({
      where: { id: deal.id },
      data,
      include: { lead: true, consultant: true },
    });

    const done = !!(updated.city && updated.district && updated.type && updated.rooms);

    return {
      ok: true,
      done,
      filled: field,
      deal: updated,
      next: done ? null : await this.wizardNextQuestion(leadId),
    };
  }
"""

    # Insert before last }
    txt2 = txt.rstrip()
    if not txt2.endswith("}"):
        raise SystemExit("Unexpected leads.service.ts ending")
    txt2 = txt2[:-1] + wizard_block + "\n}\n"
    leads_svc.write_text(txt2, encoding="utf-8")
else:
    leads_svc.write_text(txt, encoding="utf-8")

# -------------------------
# leads.module.ts patch (DI)
# -------------------------
if leads_mod.exists():
    t = leads_mod.read_text(encoding="utf-8")
    if "DealsModule" not in t:
        # add import
        t = re.sub(
            r"(import\s+.*?;\n)",
            r"\1import { DealsModule } from '../deals/deals.module';\n",
            t,
            count=1
        )
        # add to imports: [...]
        t = re.sub(
            r"imports:\s*\[([^\]]*)\]",
            lambda m: "imports: [" + (m.group(1).strip() + (", " if m.group(1).strip() else "") + "DealsModule") + "]",
            t,
            count=1
        )
        leads_mod.write_text(t, encoding="utf-8")

# -------------------------
# deals.module.ts patch (export DealsService)
# -------------------------
if deals_mod.exists():
    t = deals_mod.read_text(encoding="utf-8")
    if "exports" not in t:
        # add exports: [DealsService] into @Module
        t = re.sub(
            r"@Module\(\{\s*",
            "@Module({\n  exports: [DealsService],\n  ",
            t,
            count=1
        )
    elif "DealsService" not in t:
        t = re.sub(
            r"exports:\s*\[([^\]]*)\]",
            lambda m: "exports: [" + (m.group(1).strip() + (", " if m.group(1).strip() else "") + "DealsService") + "]",
            t,
            count=1
        )
    deals_mod.write_text(t, encoding="utf-8")

print("✅ Patch OK")
PY

say "2) Build (apps/api)"
cd "$API_DIR"
pnpm -s build
cd "$ROOT_DIR"

say "3) Test komutları (manuel)"
cat <<'EOF'

1) Yeni lead oluştur:
   curl -sS -X POST http://localhost:3001/leads \
     -H "Content-Type: application/json" \
     -d '{ "initialText": "wizard test" }'

2) LeadId ile sıradaki soru:
   curl -sS -X POST http://localhost:3001/leads/LEAD_ID/wizard/next-question | jq

3) Cevapla:
   curl -sS -X POST http://localhost:3001/leads/LEAD_ID/wizard/answer \
     -H "Content-Type: application/json" \
     -d '{ "answer": "Konya" }' | jq

4) Tekrar next-question (district/type/rooms diye gider):
   curl -sS -X POST http://localhost:3001/leads/LEAD_ID/wizard/next-question | jq

EOF

echo "✅ DONE"
