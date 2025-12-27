#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Desktop/teklif-platform"
FILE="$ROOT/apps/api/src/leads/leads.service.ts"
API_DIR="$ROOT/apps/api"

[[ -f "$FILE" ]] || { echo "❌ Bulunamadı: $FILE"; exit 1; }

echo "==> 0) Backup"
TS="$(date +"%Y%m%d-%H%M%S")"
cp "$FILE" "$FILE.bak.$TS"
echo "✅ Backup: $FILE.bak.$TS"
echo

python3 - <<'PY'
from pathlib import Path
import re

path = Path("/Users/muazgozhamam/Desktop/teklif-platform/apps/api/src/leads/leads.service.ts")
txt = path.read_text(encoding="utf-8")

# --- 1) done:true return konumu ---
m_done = None
for m in re.finditer(r"return\s*\{\s*[^;]*?\bdone\s*:\s*true\b", txt, flags=re.DOTALL):
    m_done = m
if not m_done:
    raise SystemExit("❌ 'return { ... done: true ... }' bulunamadı (bu dosyada).")

# done return çevresinden bağlam al
start = max(0, m_done.start() - 2500)
end   = min(len(txt), m_done.start() + 800)
ctx = txt[start:end]

# --- 2) Prisma erişim prefix tespiti ---
# Önce dosyada geçen .deal.update kullanımlarından prefix çıkar
prefix = None
# ör: await this.db.deal.update(
m_pref = re.search(r"await\s+([a-zA-Z0-9_\.]+)\.deal\.update\s*\(", txt)
if m_pref:
    prefix = m_pref.group(1)

# yoksa en yaygın alan adlarını dene
if not prefix:
    for cand in ["this.prisma", "this.db", "this.prismaService", "this.prismaClient"]:
        if cand in txt:
            prefix = cand
            break

# yoksa constructor'da PrismaService field adı yakala (Nest pattern)
if not prefix:
    m_ctor = re.search(r"constructor\s*\([^)]*(?:private|public|protected)\s+(?:readonly\s+)?([a-zA-Z0-9_]+)\s*:\s*PrismaService", txt)
    if m_ctor:
        prefix = "this." + m_ctor.group(1)

# --- 3) Deal id expression tespiti (done return çevresinde) ---
id_expr = None

# En güvenlisi: deal.id
if re.search(r"\bdeal\.id\b", ctx):
    id_expr = "deal.id"
# dealId değişkeni
elif re.search(r"\bdealId\b", ctx):
    id_expr = "dealId"
# return objesinde dealId: xyz
else:
    m_dealid = re.search(r"\bdealId\s*:\s*([a-zA-Z0-9_\.]+)", ctx)
    if m_dealid:
        id_expr = m_dealid.group(1)

# --- 4) Import DealStatus garanti ---
# @prisma/client import'u içine DealStatus ekle
m_imp = re.search(r"import\s*\{([^}]+)\}\s*from\s*['\"]@prisma/client['\"];?", txt)
if m_imp:
    items = [x.strip() for x in m_imp.group(1).split(",") if x.strip()]
    if "DealStatus" not in items:
        items.append("DealStatus")
        repl = "import { " + ", ".join(items) + " } from '@prisma/client';"
        txt = txt[:m_imp.start()] + repl + txt[m_imp.end():]
else:
    txt = "import { DealStatus } from '@prisma/client';\n" + txt

# Patch zaten var mı kontrol
if "Wizard tamamlandı: match'e hazır hale getir" in txt and "READY_FOR_MATCHING" in txt:
    print("ℹ️ Patch zaten var görünüyor. Yine de status OPEN kalıyorsa, doğru code-path burası değil demektir.")
    raise SystemExit(2)

# Eğer prefix veya id yoksa diagnostik bas
if not prefix or not id_expr:
    print("❌ Auto-detect eksik kaldı.")
    print(f"- prisma prefix: {prefix}")
    print(f"- id expr: {id_expr}")
    print("\n--- DIAGNOSTIC (done:true çevresi) ---")
    print(ctx)
    print("\n--- DIAGNOSTIC (dosyada .deal. geçen satırlar) ---")
    for line_no, line in enumerate(txt.splitlines(), 1):
        if ".deal." in line:
            print(f"{line_no}: {line}")
    raise SystemExit(3)

# Enjeksiyon
indent_m = re.search(r"(\n\s*)return\s*\{\s*[^;]*?\bdone\s*:\s*true\b", txt[m_done.start()-200:m_done.start()+50], flags=re.DOTALL)
indent = indent_m.group(1) if indent_m else "\n    "

inject = (
    f"{indent}// Wizard tamamlandı: match'e hazır hale getir\n"
    f"{indent}await {prefix}.deal.update({{\n"
    f"{indent}  where: {{ id: {id_expr} }},\n"
    f"{indent}  data: {{ status: DealStatus.READY_FOR_MATCHING }},\n"
    f"{indent}}});\n"
)

txt = txt[:m_done.start()] + inject + txt[m_done.start():]
path.write_text(txt, encoding="utf-8")

print("✅ Smart patch uygulandı:")
print(f"- prisma prefix = {prefix}")
print(f"- id expr = {id_expr}")
PY

echo
echo "==> 2) Prisma generate + build"
cd "$API_DIR"
pnpm -s prisma generate --schema prisma/schema.prisma
pnpm -s build
echo "✅ build OK"

echo
echo "Sonraki test:"
echo "  cd $ROOT"
echo "  kill \$(cat /tmp/teklif-api-dev.pid) 2>/dev/null || true"
echo "  ./dev-start-and-e2e.sh"
