#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="$ROOT/apps/api/src/leads/leads.service.ts"

if [[ ! -f "$FILE" ]]; then
  echo "❌ Bulunamadı: $FILE"
  exit 1
fi

TS="$(date +%Y%m%d-%H%M%S)"
BAK="$FILE.bak.$TS"
cp "$FILE" "$BAK"
echo "✅ Backup: $BAK"

python3 - <<'PY'
from pathlib import Path
import re

path = Path("apps/api/src/leads/leads.service.ts")
txt = path.read_text(encoding="utf-8")

# 1) DONE_TRUE_PATCH_* yorumlarını kaldır
txt = re.sub(r"^\s*//\s*DONE_TRUE_PATCH[^\n]*\n", "", txt, flags=re.M)

# 2) Aynı update bloğunun tekrarlarını temizle
# Esnek regex: prisma.deal.update({ where: { id: deal.id }, data: { status: DealStatus.READY_FOR_MATCHING } });
pattern = re.compile(
    r"""
    (?:\s*await\s+this\.prisma\.deal\.update\(\{\s*
        where:\s*\{\s*id:\s*deal\.id\s*\}\s*,\s*
        data:\s*\{\s*status:\s*DealStatus\.READY_FOR_MATCHING\s*\}\s*
    \}\);\s*){2,}
    """,
    re.X
)
txt = pattern.sub(
    "\n      await this.prisma.deal.update({ where: { id: deal.id }, data: { status: DealStatus.READY_FOR_MATCHING } });\n",
    txt
)

# 3) Yardımcı metod ekle (yoksa)
helper = """
  private async markDealReadyForMatching(dealId: string) {
    await this.prisma.deal.update({
      where: { id: dealId },
      data: { status: DealStatus.READY_FOR_MATCHING },
    });
  }
""".rstrip() + "\n"

if "markDealReadyForMatching(" not in txt:
    # class içinde en sona yakın ekle: son "}" kapanışından önce
    idx = txt.rfind("}\n")
    if idx == -1:
        raise SystemExit("❌ leads.service.ts beklenmedik format (class kapanışı bulunamadı).")
    txt = txt[:idx] + "\n" + helper + txt[idx:]

# 4) wizard tamamlandı bloklarında update çağrılarını helper'a çevir
txt = re.sub(
    r"await\s( )*this\.prisma\.deal\.update\(\{\s*where:\s*\{\s*id:\s*deal\.id\s*\}\s*,\s*data:\s*\{\s*status:\s*DealStatus\.READY_FOR_MATCHING\s*\}\s*\}\);\s*",
    "await this.markDealReadyForMatching(deal.id);\n      ",
    txt
)

# 5) Aynı helper çağrısı art arda geldiyse tekle
txt = re.sub(
    r"(await this\.markDealReadyForMatching\(deal\.id\);\s*){2,}",
    "await this.markDealReadyForMatching(deal.id);\n      ",
    txt
)

path.write_text(txt, encoding="utf-8")
print("✅ Cleanup OK")
PY

echo "==> Build (apps/api)"
cd "$ROOT/apps/api"
pnpm -s build
echo "✅ build OK"
