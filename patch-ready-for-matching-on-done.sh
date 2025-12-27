#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Desktop/teklif-platform"
API_DIR="$ROOT/apps/api"
FILE="$API_DIR/src/leads/leads.service.ts"

[[ -f "$FILE" ]] || { echo "❌ Bulunamadı: $FILE"; exit 1; }

echo "==> 0) Backup"
TS="$(date +"%Y%m%d-%H%M%S")"
cp "$FILE" "$FILE.bak.$TS"
echo "✅ Backup: $FILE.bak.$TS"
echo

echo "==> 1) Patch: done:true + dealId/deal.id olan return'lerden önce status set et"
python3 - <<'PY'
from pathlib import Path
import re

path = Path("/Users/muazgozhamam/Desktop/teklif-platform/apps/api/src/leads/leads.service.ts")
txt = path.read_text(encoding="utf-8")

# Prisma field adı tespit
m_ctor = re.search(r"constructor\s*\([^)]*(?:private|public|protected)\s+(?:readonly\s+)?([a-zA-Z0-9_]+)\s*:\s*PrismaService", txt)
prisma_field = m_ctor.group(1) if m_ctor else None
if not prisma_field:
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

marker = "DONE_TRUE_PATCH_READY_FOR_MATCHING"

# Hedef: return { ... done: true ... dealId: deal.id ... }
# format bağımsız: satır kırılımları/boşluklar fark etmez
ret_pat = re.compile(r"(\n[ \t]*)return\s*\{\s*([\s\S]*?)\}\s*;", re.MULTILINE)

patched = 0
out = []
last = 0

for m in ret_pat.finditer(txt):
    block = m.group(0)
    indent = m.group(1)
    body = m.group(2)

    # done:true yoksa geç
    if not re.search(r"\bdone\s*:\s*true\b", body):
        continue

    # dealId var mı? (deal.id veya değişken olabilir)
    # E2E’nin beklediği iki done-return: dealId dönüyor.
    m_dealid = re.search(r"\bdealId\s*:\s*([a-zA-Z0-9_\.]+)", body)
    if not m_dealid:
        continue

    dealid_expr = m_dealid.group(1)

    # zaten patch'li mi?
    pre = txt[max(0, m.start()-500):m.start()]
    if marker in pre:
        continue

    inject = (
        f"{indent}// {marker}\n"
        f"{indent}await {prisma_expr}.deal.update({{\n"
        f"{indent}  where: {{ id: {dealid_expr} }},\n"
        f"{indent}  data: {{ status: DealStatus.READY_FOR_MATCHING }},\n"
        f"{indent}}});\n"
    )

    # Inject'i return'ün hemen önüne koy
    txt = txt[:m.start()] + inject + txt[m.start():]
    patched += 1
    # regex iterator bozulmasın diye break edip yeniden tara
    break

# Birden fazla done:true+dealId return olabilir; hepsini patchlemek için döngüyle tekrarla
while True:
    m = None
    for mm in ret_pat.finditer(txt):
        body = mm.group(2)
        if not re.search(r"\bdone\s*:\s*true\b", body): 
            continue
        m_dealid = re.search(r"\bdealId\s*:\s*([a-zA-Z0-9_\.]+)", body)
        if not m_dealid: 
            continue
        indent = mm.group(1)
        pre = txt[max(0, mm.start()-500):mm.start()]
        if marker in pre:
            continue
        m = mm
        dealid_expr = m_dealid.group(1)
        inject = (
            f"{indent}// {marker}\n"
            f"{indent}await {prisma_expr}.deal.update({{\n"
            f"{indent}  where: {{ id: {dealid_expr} }},\n"
            f"{indent}  data: {{ status: DealStatus.READY_FOR_MATCHING }},\n"
            f"{indent}}});\n"
        )
        txt = txt[:m.start()] + inject + txt[m.start():]
        patched += 1
        break
    if not m:
        break

if patched == 0:
    raise SystemExit("❌ done:true + dealId: ... olan return bulunamadı. (leads.service.ts formatı beklenmedik)")

path.write_text(txt, encoding="utf-8")
print(f"✅ Patch OK. prisma={prisma_field} patched={patched}")
PY

echo
echo "==> 2) Build (apps/api)"
cd "$API_DIR"
pnpm -s build
echo "✅ build OK"
