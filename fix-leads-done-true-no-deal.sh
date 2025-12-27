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

echo "==> 1) return { done: true }; öncesindeki 'deal.id' kullanan injected bloğu kaldır"
python3 - <<'PY'
from pathlib import Path
import re

path = Path("/Users/muazgozhamam/Desktop/teklif-platform/apps/api/src/leads/leads.service.ts")
txt = path.read_text(encoding="utf-8")

# Hedef: ŞU ŞEKİLDE BLOK (deal.id kullanan)
# // Wizard tamamlandı: match'e hazır hale getir
# await this.prisma.deal.update({
#   where: { id: deal.id },
#   data: { status: DealStatus.READY_FOR_MATCHING },
# });
#
# return { done: true };

pat = re.compile(
    r"""
(\n\s*)//\s*Wizard\s+tamamlandı:\s*match'e\s+hazır\s+hale\s+getir\s*\n
\1await\s+this\.[a-zA-Z0-9_]+\.deal\.update\(\{\s*\n
\1\s*where:\s*\{\s*id:\s*deal\.id\s*\}\s*,\s*\n
\1\s*data:\s*\{\s*status:\s*DealStatus\.READY_FOR_MATCHING\s*\}\s*,\s*\n
\1\}\)\s*;\s*\n
(\s*)return\s*\{\s*done\s*:\s*true\s*\}\s*;
""",
    re.VERBOSE
)

m = pat.search(txt)
if not m:
    # Daha esnek ikinci deneme: this.<x> değilse, direkt "where: { id: deal.id }" yakala
    pat2 = re.compile(
        r"""
(\n\s*)//\s*Wizard\s+tamamlandı:\s*match'e\s+hazır\s+hale\s+getir\s*\n
\1await\s+[^;]+?\.deal\.update\(\{\s*\n
\1\s*where:\s*\{\s*id:\s*deal\.id\s*\}\s*,\s*\n
\1\s*data:\s*\{\s*status:\s*DealStatus\.READY_FOR_MATCHING\s*\}\s*,\s*\n
\1\}\)\s*;\s*\n
(\s*)return\s*\{\s*done\s*:\s*true\s*\}\s*;
""",
        re.VERBOSE | re.DOTALL
    )
    m = pat2.search(txt)

if not m:
    raise SystemExit("❌ Kaldırılacak blok bulunamadı. (Dosyada desen farklı olabilir.)")

# Bloğu kaldırıp return satırını koruyoruz:
# Yani sadece injected update kısmını silip, return {done:true}; kalacak.
# match() ile tüm bloğu yakaladık; bunu 'return...' kısmı hariç silmek için:
full = m.group(0)
# full içinde return kısmını bul
ret = re.search(r"return\s*\{\s*done\s*:\s*true\s*\}\s*;", full)
assert ret
kept_return = full[ret.start():ret.end()]
replacement = "\n" + kept_return  # temiz bir newline ile

txt2 = txt[:m.start()] + replacement + txt[m.end():]
path.write_text(txt2, encoding="utf-8")
print("✅ Removed injected block before 'return { done: true };' (deal.id olmayan branch).")
PY

echo
echo "==> 2) Build (apps/api)"
cd "$API_DIR"
pnpm -s build
echo "✅ build OK"
