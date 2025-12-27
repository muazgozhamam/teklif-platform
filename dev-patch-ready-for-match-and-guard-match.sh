#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
PRISMA_SCHEMA="$API_DIR/prisma/schema.prisma"
DEALS_SVC="$API_DIR/src/deals/deals.service.ts"
LEADS_SVC="$API_DIR/src/leads/leads.service.ts"

say(){ echo; echo "==> $*"; }
die(){ echo; echo "❌ $*"; exit 1; }

[[ -d "$API_DIR" ]] || die "Yanlış dizindesin. Kök: ~/Desktop/teklif-platform olmalı."

say "1) Prisma enum DealStatus içine READY_FOR_MATCH ekle"
python3 - <<'PY'
from pathlib import Path
import re, sys, datetime

p = Path("apps/api/prisma/schema.prisma")
txt = p.read_text(encoding="utf-8")

m = re.search(r"(?s)enum\s+DealStatus\s*\{(.*?)\n\}", txt)
if not m:
    print("❌ enum DealStatus bulunamadı (schema.prisma).", file=sys.stderr)
    sys.exit(2)

body = m.group(1)
if "READY_FOR_MATCH" in body:
    print("✅ READY_FOR_MATCH zaten var.")
    sys.exit(0)

# OPEN varsa hemen altına ekle; yoksa en başa ekle
lines = body.splitlines()
out = []
inserted = False
for line in lines:
    out.append(line)
    if re.search(r"\bOPEN\b", line) and not inserted:
        out.append("  READY_FOR_MATCH")
        inserted = True
if not inserted:
    out.insert(0, "  READY_FOR_MATCH")

new_body = "\n".join(out)
new_txt = txt[:m.start(1)] + new_body + txt[m.end(1):]

bak = p.with_suffix(p.suffix + f".bak.{datetime.datetime.now().strftime('%Y%m%d-%H%M%S')}")
bak.write_text(txt, encoding="utf-8")
p.write_text(new_txt, encoding="utf-8")
print("✅ schema.prisma patch OK (backup:", bak.name, ")")
PY

say "2) DealsService.match => sadece READY_FOR_MATCH iken çalışsın (guard)"
python3 - <<'PY'
from pathlib import Path
import re, sys, datetime

p = Path("apps/api/src/deals/deals.service.ts")
txt = p.read_text(encoding="utf-8")

# Import içine BadRequestException ekle
if "BadRequestException" not in txt:
    # genelde: import { Injectable, NotFoundException } from '@nestjs/common';
    txt2, n = re.subn(
        r"import\s*\{\s*([^}]+)\s*\}\s*from\s*['\"]@nestjs/common['\"];",
        lambda m: (
            "import { " + (m.group(1).strip() + ", BadRequestException") + " } from '@nestjs/common';"
            if "BadRequestException" not in m.group(1) else m.group(0)
        ),
        txt,
        count=1
    )
    if n == 0:
        print("❌ @nestjs/common import satırı bulunamadı.", file=sys.stderr)
        sys.exit(2)
    txt = txt2

# match methodunu bul
m = re.search(r"(?s)async\s+match\s*\(\s*dealId\s*:\s*string\s*\)\s*\{", txt)
if not m:
    print("❌ DealsService.match(dealId: string) bulunamadı.", file=sys.stderr)
    sys.exit(2)

# match bloğunda guard daha önce eklendiyse geç
if "READY_FOR_MATCH" in txt[m.start():m.start()+800]:
    print("✅ match guard zaten ekli görünüyor.")
    sys.exit(0)

# match içinde deal'i çektiğin yerden sonra guard koymak için:
# En güvenlisi: method başlangıcına "deal status" kontrolü eklemek,
# ama deal değişkeni bazı kodlarda sonra tanımlanıyor olabilir.
# Bu yüzden direkt başta deal'i çekip guard yapıyoruz.
inject = """
    // Guard: Wizard tamamlanmadan match yapılmasın
    const deal0 = await this.prisma.deal.findUnique({ where: { id: dealId } });
    if (!deal0) throw new NotFoundException('Deal not found');
    if (deal0.status !== 'READY_FOR_MATCH') {
      throw new BadRequestException(`Deal not ready for match (status=${deal0.status})`);
    }
"""

# match header'ın hemen altına inject
pos = m.end()
txt2 = txt[:pos] + inject + txt[pos:]

bak = p.with_suffix(p.suffix + f".bak.{datetime.datetime.now().strftime('%Y%m%d-%H%M%S')}")
bak.write_text(txt, encoding="utf-8")
p.write_text(txt2, encoding="utf-8")
print("✅ deals.service.ts patch OK (backup:", bak.name, ")")
PY

say "3) LeadsService.wizardAnswer => done=true olunca deal.status=READY_FOR_MATCH yap"
python3 - <<'PY'
from pathlib import Path
import re, sys, datetime

p = Path("apps/api/src/leads/leads.service.ts")
txt = p.read_text(encoding="utf-8")

m = re.search(r"(?s)async\s+wizardAnswer\s*\(\s*leadId\s*:\s*string\s*,\s*answer\s*:\s*string\s*\)\s*\{", txt)
if not m:
    print("❌ LeadsService.wizardAnswer(leadId: string, answer: string) bulunamadı.", file=sys.stderr)
    sys.exit(2)

# Fonksiyon içinde zaten READY_FOR_MATCH update varsa geç
block = txt[m.start():m.start()+2000]
if "READY_FOR_MATCH" in block:
    print("✅ wizardAnswer içinde READY_FOR_MATCH zaten var.")
    sys.exit(0)

# Fonksiyonun ilk "return {" öncesine inject edeceğiz.
# wizardAnswer genelde deal'i update edip return ediyor. Biz return'den hemen önce:
# - doneNow hesapla
# - doneNow true ise status update et
# Bu, mevcut akışı bozmadan sadece status'u düzeltir.
func_start = m.end()

# return pozisyonu
r = re.search(r"(?s)\n\s*return\s*\{", txt[func_start:])
if not r:
    print("❌ wizardAnswer içinde return { bulunamadı.", file=sys.stderr)
    sys.exit(2)

ret_pos = func_start + r.start()

inject = """
    // Wizard tamamlandıysa deal status'u READY_FOR_MATCH yap
    try {
      const doneNow = !!deal?.city && !!deal?.district && !!deal?.type && !!deal?.rooms;
      if (doneNow && deal?.status !== 'READY_FOR_MATCH') {
        deal = await this.prisma.deal.update({
          where: { id: deal.id },
          data: { status: 'READY_FOR_MATCH' },
          include: { lead: true, consultant: true },
        });
      }
    } catch (e) {
      // status update fail olursa wizard response'u kırmayalım (dev ergonomisi)
    }
"""

# Bu inject, fonksiyonda "deal" isimli değişken varsa çalışır. (Senin çıktında wizardAnswer response'unda "deal" var.)
# Eğer kodunda deal değişkeni farklı isimdeyse, burada onu yakalayacağız.
if "deal" not in block:
    print("❌ wizardAnswer içinde 'deal' değişkeni bulunamadı. (Patch güvenli değil)", file=sys.stderr)
    sys.exit(2)

txt2 = txt[:ret_pos] + inject + txt[ret_pos:]

bak = p.with_suffix(p.suffix + f".bak.{datetime.datetime.now().strftime('%Y%m%d-%H%M%S')}")
bak.write_text(txt, encoding="utf-8")
p.write_text(txt2, encoding="utf-8")
print("✅ leads.service.ts patch OK (backup:", bak.name, ")")
PY

say "4) Prisma format + generate + db push + build"
cd "$API_DIR"
pnpm -s prisma format --schema prisma/schema.prisma
pnpm -s prisma generate --schema prisma/schema.prisma
pnpm -s prisma db push --schema prisma/schema.prisma
pnpm -s build

say "✅ PATCH DONE"
echo
echo "Sıradaki: API restart + test"
echo "  cd $ROOT"
echo "  kill 80376 2>/dev/null || true   # sende farklı PID olabilir"
echo "  ./dev-start-and-wizard-test.sh   # server'i ayağa kaldır"
echo "  ./dev-wizard-complete-and-match.sh"
