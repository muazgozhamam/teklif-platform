#!/usr/bin/env bash
# ÇALIŞILACAK KÖK: ~/Desktop/teklif-platform
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$ROOT/dev-start-and-e2e.sh"

if [ ! -f "$TARGET" ]; then
  echo "HATA: dev-start-and-e2e.sh bulunamadı: $TARGET"
  exit 1
fi

cp "$TARGET" "$TARGET.bak.$(date +%Y%m%d-%H%M%S)"

python3 - <<'PY'
from pathlib import Path
import re

root = Path.cwd()
target = root / "dev-start-and-e2e.sh"
txt = target.read_text(encoding="utf-8")

if "==> 5) Listing create -> link -> verify" in txt:
    print("ℹ️ Zaten patchli. Değişiklik yok.")
    raise SystemExit(0)

# Anchor: "Özet:" satırını bul ve öncesine ekle
m = re.search(r"(?m)^\s*Özet\s*:\s*$", txt)
if not m:
    # alternatif: "Özet:" bazen "Özet:" bitişik olabilir
    m = re.search(r"(?m)^\s*Özet\s*:", txt)
if not m:
    raise SystemExit("❌ Anchor bulunamadı: dev-start-and-e2e.sh içinde 'Özet:' yok. (Dosya formatı değişmiş.)")

insert_pos = m.start()

addon = r'''
echo
echo "==> 5) Listing create -> link -> verify"

# actor consultant_seed_1 (dev seed)
ACTOR_ID="consultant_seed_1"

# Listing create (requires x-user-id)
CREATE_LISTING_RESP="$(curl -sS -X POST "$API_BASE/listings" \
  -H "Content-Type: application/json" \
  -H "x-user-id: $ACTOR_ID" \
  -d '{
    "title": "E2E Listing",
    "city": "Konya",
    "district": "Selçuklu",
    "type": "SATILIK",
    "rooms": "2+1"
  }'
)"
echo "LISTING_CREATE=$CREATE_LISTING_RESP"

LISTING_ID="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["id"])' "$CREATE_LISTING_RESP")"
echo "LISTING_ID=$LISTING_ID"
echo

# Link listing to deal (requires x-user-id)
LINK_RESP="$(curl -sS -X POST "$API_BASE/deals/$DEAL_ID/link-listing/$LISTING_ID" \
  -H "Content-Type: application/json" \
  -H "x-user-id: $ACTOR_ID"
)"
echo "LINK_RESP=$LINK_RESP"
echo

echo "==> Verify deal"
curl -sS "$API_BASE/deals/$DEAL_ID" | sed 's/^/DEAL: /'
echo
echo "==> Verify listing"
curl -sS "$API_BASE/listings/$LISTING_ID" -H "x-user-id: $ACTOR_ID" | sed 's/^/LISTING: /'
echo
'''

txt2 = txt[:insert_pos] + addon + txt[insert_pos:]
target.write_text(txt2, encoding="utf-8")
print("✅ Patch OK: Listing create+link+verify bloğu 'Özet:' öncesine eklendi.")
PY

chmod +x "$TARGET"
echo "✅ Patch applied: $TARGET"
