#!/usr/bin/env bash
# ÇALIŞILACAK KÖK: ~/Desktop/teklif-platform
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$ROOT/dev-start-and-e2e.sh"

if [ ! -f "$TARGET" ]; then
  echo "❌ HATA: dev-start-and-e2e.sh bulunamadı: $TARGET"
  exit 1
fi

# backup
TS="$(date +%Y%m%d-%H%M%S)"
cp "$TARGET" "$TARGET.bak.$TS"
echo "✅ Backup: $TARGET.bak.$TS"

python3 - <<'PY'
import re
from pathlib import Path

target = Path("dev-start-and-e2e.sh")
txt = target.read_text(encoding="utf-8")

# 1) Listing create bloğunu yakala:
# echo "==> Listing create"
# CREATE_RESP="$(curl ... -d 'JSON' )"
# Ama JSON çift tırnakla da olabilir; en sağlamı -d ile başlayan satırı bulup değiştirmek.
block_re = re.compile(
    r'(?ms)^echo\s+"==>\s+Listing create"\s*\n'
    r'(?:.*\n)*?^CREATE_RESP="\$\(\s*curl[^\n]*\n'
    r'(?:.*\n)*?^\s*-d\s+(?P<quote>[\'"])(?P<body>.*?)(?P=quote)\s*\n'
    r'(?:.*\n)*?^\)"\s*$'
)

m = block_re.search(txt)
if not m:
    raise SystemExit("❌ Listing create bloğu bulunamadı. (echo '==> Listing create' / CREATE_RESP curl bloğu)")

json_body = m.group("body")

# 2) JSON içinden alanları çıkar (mevcut sabit city/district/type/rooms varsayıyoruz)
# En azından title dışındaki kısmı koruyalım.
# Eğer json_body zaten bozuksa, fallback sabitleri kullanalım.
def extract(key, default=None):
    mm = re.search(rf'"{re.escape(key)}"\s*:\s*"([^"]*)"', json_body)
    return mm.group(1) if mm else default

city = extract("city", "Konya")
district = extract("district", "Selçuklu")
typ = extract("type", "SATILIK")
rooms = extract("rooms", "2+1")

# 3) Yeni -d satırı (bash değişkeni ile)
new_payload = (
    r'-d "{\"title\":\"$LISTING_TITLE\",'
    + rf'\"city\":\"{city}\",\"district\":\"{district}\",\"type\":\"{typ}\",\"rooms\":\"{rooms}\"}"'
)

# 4) LISTING_TITLE satırını CREATE_RESP’ten hemen önce ekle (idempotent olsun)
# Eğer zaten LISTING_TITLE varsa tekrar eklemeyelim.
snippet_start = txt[:m.start()]
snippet = txt[m.start():m.end()]
snippet_end = txt[m.end():]

if 'LISTING_TITLE=' not in snippet:
    # CREATE_RESP satırından önce ekle
    snippet = re.sub(
        r'(?m)^CREATE_RESP="\$\(',
        'LISTING_TITLE="Test Listing - $DEAL_ID"\n\nCREATE_RESP="$(',
        snippet,
        count=1
    )

# 5) Var olan -d satırını değiştir
snippet = re.sub(
    r'(?m)^\s*-d\s+(?:\'[^\']*\'|"[^"]*")\s*$',
    "  " + new_payload,
    snippet,
    count=1
)

# 6) Dosyayı birleştir
patched = snippet_start + snippet + snippet_end

target.write_text(patched, encoding="utf-8")
print("✅ Patch OK: dev-start-and-e2e.sh (LISTING_TITLE + JSON payload fixed)")
PY

chmod +x "$TARGET"
echo "✅ DONE"
echo
echo "Çalıştır:"
echo "  cd $ROOT"
echo "  kill \$(cat /tmp/teklif-api-dev.pid) 2>/dev/null || true"
echo "  ./dev-start-and-e2e.sh"
