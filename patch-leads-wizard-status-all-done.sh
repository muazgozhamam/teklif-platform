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

echo "==> 1) Patch (tüm done:true dönüşlerinden önce READY_FOR_MATCHING set)"
python3 - <<'PY'
from pathlib import Path
import re

path = Path("/Users/muazgozhamam/Desktop/teklif-platform/apps/api/src/leads/leads.service.ts")
txt = path.read_text(encoding="utf-8")

# 1) Prisma field adı tespit (Nest constructor pattern)
m_ctor = re.search(r"constructor\s*\([^)]*(?:private|public|protected)\s+(?:readonly\s+)?([a-zA-Z0-9_]+)\s*:\s*PrismaService", txt)
prisma_field = m_ctor.group(1) if m_ctor else None

# Alternatif: dosyada "this.<x>.deal." kullanan bir şey var mı?
if not prisma_field:
    m_use = re.search(r"\bthis\.([a-zA-Z0-9_]+)\.deal\.", txt)
    if m_use:
        prisma_field = m_use.group(1)

if not prisma_field:
    raise SystemExit("❌ PrismaService field adı tespit edilemedi. (constructor'da PrismaService yok / farklı isim)")

prisma_expr = f"this.{prisma_field}"

# 2) @prisma/client import'una DealStatus ekle
m_imp = re.search(r"import\s*\{([^}]+)\}\s*from\s*['\"]@prisma/client['\"];?", txt)
if m_imp:
    items = [x.strip() for x in m_imp.group(1).split(",") if x.strip()]
    if "DealStatus" not in items:
        items.append("DealStatus")
        repl = "import { " + ", ".join(items) + " } from '@prisma/client';"
        txt = txt[:m_imp.start()] + repl + txt[m_imp.end():]
else:
    txt = "import { DealStatus } from '@prisma/client';\n" + txt

# 3) done:true return'lerinin hepsini bul
# Hedefler:
# - return { done: true };
# - return { done: true, dealId: deal.id };
# - return { ok: true, done: true, dealId: deal.id };
ret_pat = re.compile(r"(\n\s*)return\s*\{\s*([^;]*?\bdone\s*:\s*true\b[^;]*?)\};", re.DOTALL)

matches = list(ret_pat.finditer(txt))
if not matches:
    raise SystemExit("❌ done:true return blokları bulunamadı.")

# 4) Her match için: hemen öncesinde status update yoksa ekle
# ID expr: Önce 'deal.id' var mı? Yoksa return objesinde 'dealId: <expr>' yakala.
def make_inject(indent: str, id_expr: str) -> str:
    return (
        f"{indent}// Wizard tamamlandı: match'e hazır hale getir\n"
        f"{indent}await {prisma_expr}.deal.update({{\n"
        f"{indent}  where: {{ id: {id_expr} }},\n"
        f"{indent}  data: {{ status: DealStatus.READY_FOR_MATCHING }},\n"
        f"{indent}}});\n"
    )

# Insert yaparken offset kaymasını önlemek için sondan başa gidiyoruz
patched_count = 0
for m in reversed(matches):
    indent = m.group(1)
    body = m.group(2)

    # Zaten patch varsa ekleme
    before_slice = txt[max(0, m.start()-400):m.start()]
    if "Wizard tamamlandı: match'e hazır hale getir" in before_slice and "READY_FOR_MATCHING" in before_slice:
        continue

    id_expr = None
    if "deal.id" in body:
        id_expr = "deal.id"
    else:
        m_dealid = re.search(r"\bdealId\s*:\s*([a-zA-Z0-9_\.]+)", body)
        if m_dealid:
            id_expr = m_dealid.group(1)

    # dealId yoksa, bu return {done:true} muhtemelen deal değişkeni scope'ta
    if not id_expr:
        # En pratik varsayım: scope'ta deal var.
        id_expr = "deal.id"

    inject = make_inject(indent, id_expr)
    txt = txt[:m.start()] + inject + txt[m.start():]
    patched_count += 1

path.write_text(txt, encoding="utf-8")
print(f"✅ Patch OK. PrismaField={prisma_field} | patched_returns={patched_count}")
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
echo "  kill \$(cat /tmp/teklif-api-dev.pid) 2>/dev/null || true"
echo "  ./dev-start-and-e2e.sh"
