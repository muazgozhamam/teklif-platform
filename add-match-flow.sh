#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"
CTRL="$API_DIR/src/deals/deals.controller.ts"
SVC="$API_DIR/src/deals/deals.service.ts"

say(){ printf "\n==> %s\n" "$*"; }
die(){ printf "\n❌ %s\n" "$*" >&2; exit 1; }

[[ -f "$SCHEMA" ]] || die "schema.prisma yok: $SCHEMA"
[[ -f "$CTRL" ]] || die "deals.controller.ts yok: $CTRL"
[[ -f "$SVC"  ]] || die "deals.service.ts yok: $SVC"

say "0) Backup"
cp -f "$SCHEMA" "$SCHEMA.bak.$(date +%Y%m%d-%H%M%S)"
cp -f "$CTRL"   "$CTRL.bak.$(date +%Y%m%d-%H%M%S)"
cp -f "$SVC"    "$SVC.bak.$(date +%Y%m%d-%H%M%S)"

say "1) Prisma enum DealStatus: ASSIGNED ekle (yoksa)"
python3 - "$SCHEMA" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

m = re.search(r'(?s)\benum\s+DealStatus\s*\{(.*?)\n\}', txt)
if not m:
    print("NO_ENUM_DealStatus")
    raise SystemExit(2)

inside = m.group(1)
if re.search(r'(?m)^\s*ASSIGNED\s*$', inside):
    print("ALREADY_PRESENT")
    raise SystemExit(0)

lines = inside.splitlines()
out = []
inserted = False
for line in lines:
    out.append(line)
    if (not inserted) and re.search(r'^\s*READY_FOR_MATCHING\s*$', line):
        out.append("  ASSIGNED")
        inserted = True
if not inserted:
    out.append("  ASSIGNED")

new_inside = "\n".join(out)
new_txt = txt[:m.start()] + f"enum DealStatus {{\n{new_inside}\n}}" + txt[m.end():]
p.write_text(new_txt, encoding="utf-8")
print("PATCHED")
PY

say "2) model Deal: consultantId alanı yoksa ekle (opsiyonel + relation)"
python3 - "$SCHEMA" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

m = re.search(r'(?s)\bmodel\s+Deal\s*\{(.*?)\n\}', txt)
if not m:
    print("NO_MODEL_DEAL")
    raise SystemExit(2)

block = m.group(0)
inside = m.group(1)

# Deal içinde consultantId var mı?
if re.search(r'(?m)^\s*consultantId\s+\w+', inside):
    print("DEAL_ALREADY_HAS_CONSULTANT")
    raise SystemExit(0)

# User model var mı? (relation için)
if not re.search(r'(?s)\bmodel\s+User\s*\{', txt):
    print("NO_MODEL_USER (relation ekleyemem)")
    raise SystemExit(3)

# insert yeri: leadId/lead satırlarının altına koymayı dene; yoksa bloğun sonuna ekle
lines = inside.splitlines()
out = []
inserted = False
for line in lines:
    out.append(line)
    if (not inserted) and re.search(r'^\s*leadId\s+', line):
        # leadId'den hemen sonra eklemek genelde temiz
        out.append("  consultantId String?")
        out.append('  consultant   User?   @relation(name: "DealConsultant", fields: [consultantId], references: [id], onDelete: SetNull)')
        inserted = True

if not inserted:
    out.append("  consultantId String?")
    out.append('  consultant   User?   @relation(name: "DealConsultant", fields: [consultantId], references: [id], onDelete: SetNull)')

new_inside = "\n".join(out)
new_block = f"model Deal {{\n{new_inside}\n}}"

txt2 = txt[:m.start()] + new_block + txt[m.end():]
p.write_text(txt2, encoding="utf-8")
print("PATCHED_DEAL_CONSULTANT")
PY

say "3) DealsService: matchDeal(id) ekle (yoksa)"
python3 - "$SVC" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

if "async matchDeal(" in txt:
    print("ALREADY_PRESENT")
    raise SystemExit(0)

# DealStatus importu yoksa ekle (bazı projelerde @prisma/client'tan gelir)
# Biz runtime-safe gidelim: string set ederken Prisma enum'a takılmaz; ama TS derleyebilir.
# Bu yüzden DealStatus kullanmadan string olarak set ediyoruz.

# class içine method ekleyeceğiz: son '}' kapanmadan hemen önce
m = re.search(r'(?s)\bexport\s+class\s+DealsService\b.*?\n\}', txt)
if not m:
    print("NO_CLASS_DEALSSERVICE")
    raise SystemExit(2)

insert_at = txt.rfind("\n}")
if insert_at == -1:
    print("NO_CLASS_END")
    raise SystemExit(3)

method = r'''
  async matchDeal(dealId: string) {
    // 1) Deal mevcut mu?
    const deal = await this.prisma.deal.findUnique({ where: { id: dealId } });
    if (!deal) {
      // Nest standard
      throw new Error(`Deal not found: ${dealId}`);
    }

    // 2) Uygun consultant bul (önce role=CONSULTANT dene; yoksa ilk kullanıcı)
    // Not: role alanı enum/string olabilir; TS için any cast.
    const consultant =
      (await this.prisma.user.findFirst({ where: { role: "CONSULTANT" as any } as any })) ||
      (await this.prisma.user.findFirst());

    if (!consultant) {
      throw new Error("No consultant/user found to assign.");
    }

    // 3) Deal'i ASSIGNED yap ve consultantId yaz
    return this.prisma.deal.update({
      where: { id: dealId },
      data: {
        status: "ASSIGNED" as any,
        consultantId: consultant.id,
      } as any,
    });
  }
'''

txt2 = txt[:insert_at] + method + "\n" + txt[insert_at:]
p.write_text(txt2, encoding="utf-8")
print("PATCHED")
PY

say "4) DealsController: POST /deals/:id/match ekle (yoksa)"
python3 - "$CTRL" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

if re.search(r'@Post\(\s*[\'"]\:id\/match[\'"]\s*\)', txt):
    print("ALREADY_PRESENT")
    raise SystemExit(0)

# Controller class içinde advance methodunun altına ekle
# advance(...) { return this.deals.advanceDeal... }
m = re.search(r'(?s)(@Post\(\s*[\'"]\:id\/advance[\'"]\s*\)\s*\n\s*advance\s*\(.*?\)\s*\{.*?\n\s*\})', txt)
if not m:
    print("NO_ADVANCE_METHOD_PATTERN")
    raise SystemExit(2)

advance_block = m.group(1)

inject = advance_block + r'''

  @Post(':id/match')
  match(@Param('id') id: string) {
    return this.deals.matchDeal(id);
  }
'''

txt2 = txt.replace(advance_block, inject, 1)
p.write_text(txt2, encoding="utf-8")
print("PATCHED")
PY

say "5) Prisma generate + db push + build"
cd "$API_DIR"
pnpm -s prisma generate --schema prisma/schema.prisma
pnpm -s prisma db push --schema prisma/schema.prisma
pnpm -s build

say "✅ DONE"
echo
echo "Test (manuel hızlı):"
echo '  curl -s http://localhost:3001/health'
echo
echo "Sonraki adım: E2E match script'i ekleyelim."
