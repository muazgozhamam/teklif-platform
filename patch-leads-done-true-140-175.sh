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

echo "==> 1) Patch: iki return satırının üstüne status update enjekte et"
python3 - <<'PY'
from pathlib import Path
import re

path = Path("/Users/muazgozhamam/Desktop/teklif-platform/apps/api/src/leads/leads.service.ts")
txt = path.read_text(encoding="utf-8")

# Prisma field adı (senin önceki patch’ten: PrismaField=prisma)
# Ama yine de otomatik yakalayalım:
m_ctor = re.search(r"constructor\s*\([^)]*(?:private|public|protected)\s+(?:readonly\s+)?([a-zA-Z0-9_]+)\s*:\s*PrismaService", txt)
prisma_field = m_ctor.group(1) if m_ctor else None
if not prisma_field:
    # fallback: dosyada this.<x>.deal. geçen ilkini yakala
    m_use = re.search(r"\bthis\.([a-zA-Z0-9_]+)\.deal\.", txt)
    prisma_field = m_use.group(1) if m_use else None
if not prisma_field:
    raise SystemExit("❌ Prisma field adı bulunamadı (constructor PrismaService yok).")

prisma_expr = f"this.{prisma_field}"

# DealStatus import garanti
m_imp = re.search(r"import\s*\{([^}]+)\}\s*from\s*['\"]@prisma/client['\"];?", txt)
if m_imp:
    items = [x.strip() for x in m_imp.group(1).split(",") if x.strip()]
    if "DealStatus" not in items:
        items.append("DealStatus")
        repl = "import { " + ", ".join(items) + " } from '@prisma/client';"
        txt = txt[:m_imp.start()] + repl + txt[m_imp.end():]
else:
    txt = "import { DealStatus } from '@prisma/client';\n" + txt

targets = [
    "return { done: true, dealId: deal.id };",
    "return { ok: true, done: true, dealId: deal.id };",
]

def inject_before(line: str, text: str) -> str:
    # satır başındaki indent’i al
    idx = text.find(line)
    if idx == -1:
        return text
    # satır başlangıcı
    bol = text.rfind("\n", 0, idx) + 1
    indent = re.match(r"\s*", text[bol:idx]).group(0)

    marker = "Wizard tamamlandı: match'e hazır hale getir (DONE_TRUE_PATCH)"
    # Aynı target için daha önce eklenmiş mi kontrol
    pre = text[max(0, bol-400):bol]
    if marker in pre:
        return text

    inject = (
        f"{indent}// {marker}\n"
        f"{indent}await {prisma_expr}.deal.update({{\n"
        f"{indent}  where: {{ id: deal.id }},\n"
        f"{indent}  data: {{ status: DealStatus.READY_FOR_MATCHING }},\n"
        f"{indent}}});\n"
    )
    return text[:bol] + inject + text[bol:]

patched = 0
for t in targets:
    before = txt
    txt = inject_before(t, txt)
    if txt != before:
        patched += 1

if patched == 0:
    raise SystemExit("❌ Hedef return satırları bulunamadı (format farklı). Dosyada satırlar birebir böyle değil.")

path.write_text(txt, encoding="utf-8")
print(f"✅ Patch OK. prisma={prisma_field} | patched_targets={patched}")
PY

echo
echo "==> 2) Build (apps/api)"
cd "$API_DIR"
pnpm -s build
echo "✅ build OK"
echo
echo "Sonraki test:"
echo "  cd $ROOT"
echo "  kill \$(cat /tmp/teklif-api-dev.pid) 2>/dev/null || true"
echo "  ./dev-start-and-e2e.sh"
