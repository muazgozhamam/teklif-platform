#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Desktop/teklif-platform"
API_DIR="$ROOT/apps/api"
FILE="$API_DIR/src/deals/deals.service.ts"

[[ -f "$FILE" ]] || { echo "❌ Bulunamadı: $FILE"; exit 1; }

echo "==> 0) Backup"
TS="$(date +"%Y%m%d-%H%M%S")"
BAK="$FILE.bak.$TS"
cp "$FILE" "$BAK"
echo "✅ Backup: $BAK"
echo

echo "==> 1) Guard compare: 'READY_FOR_MATCH' -> DealStatus.READY_FOR_MATCHING"
python3 - <<'PY'
from pathlib import Path
import re

path = Path(r"/Users/muazgozhamam/Desktop/teklif-platform/apps/api/src/deals/deals.service.ts")
txt = path.read_text(encoding="utf-8")

# 1) string literal compare fix
before = txt
txt = txt.replace("!== 'READY_FOR_MATCH'", "!== DealStatus.READY_FOR_MATCHING")
txt = txt.replace("=== 'READY_FOR_MATCH'", "=== DealStatus.READY_FOR_MATCHING")

# bazı patchlerde çift tırnak olabilir
txt = txt.replace('!== "READY_FOR_MATCH"', "!== DealStatus.READY_FOR_MATCHING")
txt = txt.replace('=== "READY_FOR_MATCH"', "=== DealStatus.READY_FOR_MATCHING")

if txt == before:
    raise SystemExit("❌ 'READY_FOR_MATCH' karşılaştırması bulunamadı. Dosyada farklı yazılmış olabilir.")

# 2) DealStatus import garanti et
if "DealStatus" not in txt:
    raise SystemExit("❌ Dosyada DealStatus hiç geçmiyor. Guard satırını farklı yere eklemiş olabilirsin.")

# @prisma/client import'u kontrol et: DealStatus yoksa ekle
m = re.search(r"import\s*\{([^}]+)\}\s*from\s*['\"]@prisma/client['\"];?", txt)
if m:
    items = [x.strip() for x in m.group(1).split(",") if x.strip()]
    if "DealStatus" not in items:
        # ekle (sona)
        items.append("DealStatus")
        repl = "import { " + ", ".join(items) + " } from '@prisma/client';"
        txt = txt[:m.start()] + repl + txt[m.end():]
else:
    # yoksa yeni import ekle (en üste)
    txt = "import { DealStatus } from '@prisma/client';\n" + txt

path.write_text(txt, encoding="utf-8")
print("✅ Patch OK")
PY

echo
echo "==> 2) Build (apps/api)"
cd "$API_DIR"
pnpm -s build
echo "✅ build OK"
echo
echo "Not: Eğer dev server açıksa restart edip test et:"
echo "  cd $ROOT"
echo "  ./dev-start-and-wizard-test.sh"
echo "  ./dev-wizard-complete-and-match.sh"
