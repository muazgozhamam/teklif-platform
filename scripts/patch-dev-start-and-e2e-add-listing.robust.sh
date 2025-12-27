#!/usr/bin/env bash
# ÇALIŞILACAK KÖK: ~/Desktop/teklif-platform
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$ROOT/dev-start-and-e2e.sh"

if [ ! -f "$TARGET" ]; then
  echo "❌ $TARGET bulunamadı"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re
import sys
from datetime import datetime

target = Path(__file__).resolve().parent.parent / "dev-start-and-e2e.sh"
txt = target.read_text(encoding="utf-8", errors="replace")

# normalize line endings for matching (don’t change semantics)
norm = txt.replace("\r\n", "\n").replace("\r", "\n")

marker = "==> 5) Listing create -> link -> verify"
if marker in norm:
    print("ℹ️ Patch zaten uygulanmış görünüyor (marker bulundu). Çıkıyorum.")
    sys.exit(0)

# Find insertion point: first occurrence of a line that contains Özet:
# Accept variants: Özet:, echo "Özet:", echo 'Özet:' etc.
lines = norm.split("\n")
insert_idx = None
for i, line in enumerate(lines):
    if "Özet:" in line:
        insert_idx = i
        break

if insert_idx is None:
    # fallback: "Durdurmak için:" before that
    for i, line in enumerate(lines):
        if "Durdurmak için" in line:
            insert_idx = i
            break

if insert_idx is None:
    print("❌ Anchor bulunamadı: 'Özet:' veya 'Durdurmak için' yok. Dosyadan 1-140 arası paylaş.")
    sys.exit(1)

addon = r'''
echo
echo "==> 5) Listing create -> link -> verify"

# actor = consultant (match ile set edilen consultantId)
ACTOR_ID="${CONSULTANT_ID:-consultant_seed_1}"

# Listing create (DRAFT)
CREATE_RESP="$(curl -sS -X POST "$API_BASE/listings" \
  -H "Content-Type: application/json" \
  -H "x-user-id: $ACTOR_ID" \
  -d '{"title":"Test Listing","city":"Konya","district":"Selçuklu","type":"SATILIK","rooms":"2+1"}'
)"
echo "CREATE_RESP=$CREATE_RESP"

LISTING_ID="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("id",""))' <<<"$CREATE_RESP" 2>/dev/null || true)"
if [ -z "${LISTING_ID:-}" ]; then
  echo "❌ LISTING_ID parse edilemedi. CREATE_RESP yukarıda."
  exit 1
fi

echo "✅ LISTING_ID=$LISTING_ID"
echo

# Link listing to deal
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

# Insert addon before the anchor line
new_lines = lines[:insert_idx] + addon.strip("\n").split("\n") + [""] + lines[insert_idx:]
patched = "\n".join(new_lines)

# Write back preserving original newline style as best as possible:
# If original had \r\n, restore it
if "\r\n" in txt:
    patched = patched.replace("\n", "\r\n")

# Backup + write
bak = target.with_suffix(f".sh.bak.{datetime.now().strftime('%Y%m%d-%H%M%S')}")
bak.write_text(txt, encoding="utf-8")
target.write_text(patched, encoding="utf-8")

print(f"✅ Patch OK: {target}")
print(f"✅ Backup : {bak}")
PY
