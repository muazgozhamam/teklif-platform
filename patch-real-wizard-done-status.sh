#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Desktop/teklif-platform"
API_DIR="$ROOT/apps/api"
SRC_DIR="$API_DIR/src"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"
echo "SRC_DIR=$SRC_DIR"
echo

[[ -d "$SRC_DIR" ]] || { echo "❌ src yok: $SRC_DIR"; exit 1; }

echo "==> 1) Aday dosyaları bul (wizard + done:true)"
python3 - <<'PY'
from pathlib import Path
import re

src = Path("/Users/muazgozhamam/Desktop/teklif-platform/apps/api/src")
candidates = []
for p in src.rglob("*.ts"):
    try:
        t = p.read_text(encoding="utf-8")
    except Exception:
        continue
    if "wizard" in t and re.search(r"\bdone\s*:\s*true\b", t):
        score = t.count("wizard") + len(re.findall(r"\bdone\s*:\s*true\b", t))*3
        candidates.append((score, str(p)))

candidates.sort(reverse=True)
if not candidates:
    raise SystemExit("❌ Aday bulunamadı. 'wizard' veya 'done: true' farklı yazılmış olabilir.")

print("Adaylar (skor yüksek = daha olası):")
for s,p in candidates[:12]:
    print(f"- {s:>3}  {p}")
PY
echo

echo "==> 2) Aday dosyalara patch uygula (done:true return öncesi status set)"
python3 - <<'PY'
from pathlib import Path
import re
from datetime import datetime

ROOT = Path("/Users/muazgozhamam/Desktop/teklif-platform")
src = ROOT / "apps/api/src"

def patch_file(path: Path) -> bool:
    txt = path.read_text(encoding="utf-8")

    # Zaten patch'li ise dokunma
    if "Wizard tamamlandı: match'e hazır hale getir" in txt and "READY_FOR_MATCHING" in txt:
        return False

    # done:true dönen return objesini hedefle (en az bir tane)
    # return { ..., done: true, ... }
    pat = re.compile(r"(\n\s*)return\s*\{\s*[^;]*?\bdone\s*:\s*true\b", re.DOTALL)
    matches = list(pat.finditer(txt))
    if not matches:
        return False

    # En SON done:true return'u patchle (final state genelde en sonda)
    m = matches[-1]
    indent = m.group(1)

    # DealStatus import garanti
    imp = re.search(r"import\s*\{([^}]+)\}\s*from\s*['\"]@prisma/client['\"];?", txt)
    if imp:
        items = [x.strip() for x in imp.group(1).split(",") if x.strip()]
        if "DealStatus" not in items:
            items.append("DealStatus")
            repl = "import { " + ", ".join(items) + " } from '@prisma/client';"
            txt = txt[:imp.start()] + repl + txt[imp.end():]
    else:
        txt = "import { DealStatus } from '@prisma/client';\n" + txt

    # Prisma service kullanımına göre update çağrısı seç
    # Öncelik: this.prisma.deal.update -> varsa onu kullan
    prisma_expr = None
    if "this.prisma" in txt:
        prisma_expr = "this.prisma"
    elif "prisma." in txt:
        prisma_expr = "prisma"
    else:
        # En çok görülen isimler
        for name in ["prismaService", "db", "client"]:
            if name in txt:
                prisma_expr = name
                break

    if not prisma_expr:
        # prisma erişimi yoksa patch riskli; dokunma
        return False

    # Deal id kaynağı: deal.id varsa onu kullan, yoksa dealId değişkeni
    id_expr = None
    if re.search(r"\bdeal\.id\b", txt):
        id_expr = "deal.id"
    elif re.search(r"\bdealId\b", txt):
        id_expr = "dealId"
    elif re.search(r"\bDEAL_ID\b", txt):
        id_expr = "DEAL_ID"

    if not id_expr:
        # Bazı kodlarda response içinde dealId field'ı var; onu kullanmaya çalış
        # return objesinde dealId: xxx arayalım (yakın çevrede)
        window = txt[m.start():m.start()+1200]
        m_id = re.search(r"\bdealId\s*:\s*([a-zA-Z0-9_\.]+)", window)
        if m_id:
            id_expr = m_id.group(1)

    if not id_expr:
        return False

    inject = (
        f"{indent}// Wizard tamamlandı: match'e hazır hale getir\n"
        f"{indent}await {prisma_expr}.deal.update({{\n"
        f"{indent}  where: {{ id: {id_expr} }},\n"
        f"{indent}  data: {{ status: DealStatus.READY_FOR_MATCHING }},\n"
        f"{indent}}});\n"
    )

    txt = txt[:m.start()] + inject + txt[m.start():]
    path.write_text(txt, encoding="utf-8")
    return True

# Patch uygulanacak adayları seç: wizard+done:true içerenler
cands = []
for p in src.rglob("*.ts"):
    t = p.read_text(encoding="utf-8", errors="ignore")
    if "wizard" in t and re.search(r"\bdone\s*:\s*true\b", t):
        score = t.count("wizard") + len(re.findall(r"\bdone\s*:\s*true\b", t))*3
        cands.append((score, p))
cands.sort(reverse=True)

patched = []
for score, p in cands[:8]:  # ilk 8 adayı dene
    bak = p.with_suffix(p.suffix + f".bak.{datetime.now().strftime('%Y%m%d-%H%M%S')}")
    bak.write_text(p.read_text(encoding="utf-8"), encoding="utf-8")
    ok = patch_file(p)
    if ok:
        patched.append(str(p))

if not patched:
    raise SystemExit("❌ Hiçbir dosyaya güvenli patch uygulanamadı. (Prisma erişimi veya deal id bulunamadı.)")

print("✅ Patch uygulanan dosyalar:")
for f in patched:
    print("-", f)
PY

echo
echo "==> 3) Prisma generate + build (apps/api)"
cd "$API_DIR"
pnpm -s prisma generate --schema prisma/schema.prisma
pnpm -s build
echo "✅ build OK"

echo
echo "Sonraki test:"
echo "  cd $ROOT"
echo "  kill \$(cat /tmp/teklif-api-dev.pid) 2>/dev/null || true"
echo "  ./dev-start-and-e2e.sh"
