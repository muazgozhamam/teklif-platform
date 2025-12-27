#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Desktop/teklif-platform"
API_DIR="$ROOT/apps/api"
FILE="$API_DIR/src/leads/leads.service.ts"

[[ -f "$FILE" ]] || { echo "❌ Bulunamadı: $FILE"; exit 1; }

echo "==> 0) Backup"
TS="$(date +"%Y%m%d-%H%M%S")"
BAK="$FILE.bak.$TS"
cp "$FILE" "$BAK"
echo "✅ Backup: $BAK"
echo

echo "==> 1) leads.service.ts içinde 'done: true' dönüşünü patch'le (status READY_FOR_MATCHING)"
python3 - <<'PY'
from pathlib import Path
import re

path = Path("/Users/muazgozhamam/Desktop/teklif-platform/apps/api/src/leads/leads.service.ts")
txt = path.read_text(encoding="utf-8")

# 1) @prisma/client import'una DealStatus ekle / yoksa ekle
m = re.search(r"import\s*\{([^}]+)\}\s*from\s*['\"]@prisma/client['\"];?", txt)
if m:
    items = [x.strip() for x in m.group(1).split(",") if x.strip()]
    if "DealStatus" not in items:
        items.append("DealStatus")
        repl = "import { " + ", ".join(items) + " } from '@prisma/client';"
        txt = txt[:m.start()] + repl + txt[m.end():]
else:
    # en üste ekle
    txt = "import { DealStatus } from '@prisma/client';\n" + txt

# 2) done:true dönen return bloğunu bul
# Hedef: return { ... done: true ... }
# Bu noktadan hemen önce deal status update ekleyeceğiz.
pat = re.compile(r"(\n\s*)return\s*\{\s*[^}]*\bdone\s*:\s*true\b", re.DOTALL)

mm = list(pat.finditer(txt))
if not mm:
    raise SystemExit("❌ leads.service.ts içinde 'return { ... done: true ... }' bulunamadı. Wizard answer başka dosyada olabilir.")

# Çoklu ise en sonuncusunu patchlemek genelde doğru (final cevap)
m2 = mm[-1]
indent = m2.group(1)

# deal id için en güvenli varsayım: scope'ta 'deal' değişkeni var.
# yoksa derleme hatası alırsın; o durumda bir sonraki turda otomatik tespitli patch yaparız.
inject = (
    f"{indent}// Wizard tamamlandı: match'e hazır hale getir\n"
    f"{indent}await this.prisma.deal.update({{\n"
    f"{indent}  where: {{ id: deal.id }},\n"
    f"{indent}  data: {{ status: DealStatus.READY_FOR_MATCHING }},\n"
    f"{indent}}});\n"
)

# Zaten benzer bir update varsa çift eklemeyelim
if "READY_FOR_MATCHING" in txt and "Wizard tamamlandı" in txt:
    print("ℹ️ Patch zaten uygulanmış görünüyor (skip).")
else:
    txt = txt[:m2.start()] + inject + txt[m2.start():]

path.write_text(txt, encoding="utf-8")
print("✅ Patch OK (wizard done => status READY_FOR_MATCHING)")
PY

echo
echo "==> 2) Prisma generate + build (apps/api)"
cd "$API_DIR"
pnpm -s prisma generate --schema prisma/schema.prisma
pnpm -s build
echo "✅ build OK"
echo
echo "Sonraki test:"
echo "  cd $ROOT"
echo "  ./dev-start-and-e2e.sh"
