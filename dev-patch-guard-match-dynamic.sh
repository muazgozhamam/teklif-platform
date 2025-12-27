#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
FILE="$ROOT/apps/api/src/deals/deals.service.ts"

say(){ echo; echo "==> $*"; }
die(){ echo; echo "❌ $*"; exit 1; }

[[ -f "$FILE" ]] || die "Dosya yok: $FILE (yanlış dizin?)"

say "0) Hızlı tespit: ASSIGNED yazan satırlar"
rg -n "ASSIGNED" "$FILE" || true

say "1) DealsService içindeki ASSIGNED yapan fonksiyona guard patch"
python3 - <<'PY'
from pathlib import Path
import re, sys, datetime

p = Path("apps/api/src/deals/deals.service.ts")
txt = p.read_text(encoding="utf-8")

# 1) @nestjs/common import'larına BadRequestException ekle (yoksa)
m_imp = re.search(r"import\s*\{\s*([^}]+)\s*\}\s*from\s*['\"]@nestjs/common['\"];", txt)
if not m_imp:
    print("❌ @nestjs/common import satırı bulunamadı.", file=sys.stderr)
    sys.exit(2)

imp_inner = m_imp.group(1)
if "BadRequestException" not in imp_inner:
    new_inner = imp_inner.strip()
    # virgül düzeni
    if new_inner.endswith(","):
        new_inner = new_inner[:-1]
    new_inner = new_inner + ", BadRequestException"
    txt = txt[:m_imp.start(1)] + new_inner + txt[m_imp.end(1):]

# 2) ASSIGNED update patternini bul (en az 1 tane olmalı)
# Hem "status: 'ASSIGNED'" hem "status: DealStatus.ASSIGNED" varyantlarını yakala
pat_assigned = re.compile(r"status\s*:\s*(?:'ASSIGNED'|\"ASSIGNED\"|DealStatus\.ASSIGNED)\b")
m_ass = pat_assigned.search(txt)
if not m_ass:
    print("❌ deals.service.ts içinde ASSIGNED status update bulunamadı. (match/assign mantığı farklı olabilir)", file=sys.stderr)
    sys.exit(3)

pos = m_ass.start()

# 3) Bu ASSIGNED set eden kodun bulunduğu fonksiyonun başlığını geriye doğru bul
# En yakın "async <name>(...){"
hdr_pat = re.compile(r"async\s+([A-Za-z0-9_]+)\s*\([^)]*\)\s*\{")
headers = list(hdr_pat.finditer(txt, 0, pos))
if not headers:
    print("❌ ASSIGNED bloğu için function header bulunamadı.", file=sys.stderr)
    sys.exit(4)

hdr = headers[-1]
fn_name = hdr.group(1)
fn_body_start = hdr.end()

# 4) Guard daha önce eklenmiş mi?
window = txt[fn_body_start:fn_body_start+800]
if "Deal not ready for match" in window or "READY_FOR_MATCH" in window:
    print(f"✅ Guard zaten var gibi görünüyor. (function={fn_name})")
    sys.exit(0)

inject = f"""
    // Guard: Wizard tamamlanmadan (READY_FOR_MATCH) assign/match yapılmasın
    const deal0 = await this.prisma.deal.findUnique({{ where: {{ id: dealId }} }});
    if (!deal0) throw new NotFoundException('Deal not found');
    if (deal0.status !== 'READY_FOR_MATCH') {{
      throw new BadRequestException(`Deal not ready for match (status=${{deal0.status}})`);
    }}
"""

# 5) Hangi parametre adı kullanılıyor? dealId olmayabilir.
# header içindeki parametre adını çek: async fn(<type> <paramName> ... )
hdr_text = txt[hdr.start():hdr.end()]
m_param = re.search(r"\(\s*([A-Za-z0-9_]+)\s*:\s*string\b", hdr_text)
param_name = m_param.group(1) if m_param else "dealId"
inject = inject.replace("dealId", param_name)

# 6) Yaz
bak = p.with_suffix(p.suffix + f".bak.{datetime.datetime.now().strftime('%Y%m%d-%H%M%S')}")
bak.write_text(txt, encoding="utf-8")

txt2 = txt[:fn_body_start] + inject + txt[fn_body_start:]
p.write_text(txt2, encoding="utf-8")

print(f"✅ Guard eklendi. Function={fn_name} param={param_name}")
print(f"✅ Backup: {bak.name}")
PY

say "2) Build (apps/api)"
cd "$ROOT/apps/api"
pnpm -s prisma format --schema prisma/schema.prisma
pnpm -s prisma generate --schema prisma/schema.prisma
pnpm -s build

say "✅ DONE"
echo
echo "Test:"
echo "  cd $ROOT"
echo "  kill 80376 2>/dev/null || true   # sende farklı PID olabilir"
echo "  ./dev-start-and-wizard-test.sh"
echo "  ./dev-wizard-complete-and-match.sh"
