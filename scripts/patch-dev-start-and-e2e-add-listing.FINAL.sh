#!/usr/bin/env bash
# ÇALIŞILACAK KÖK: ~/Desktop/teklif-platform
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$ROOT/dev-start-and-e2e.sh"

if [ ! -f "$TARGET" ]; then
  echo "❌ TARGET yok: $TARGET"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re
from datetime import datetime
import sys

root = Path.cwd()  # script repo root'ta çalıştırılacak
target = root / "dev-start-and-e2e.sh"
txt = target.read_text(encoding="utf-8", errors="replace")

# normalize line endings for search
norm = txt.replace("\r\n","\n").replace("\r","\n")

marker = "==> 5) Listing create -> link -> verify"
if marker in norm:
    print("ℹ️ Patch zaten var (marker bulundu).")
    sys.exit(0)

lines = norm.split("\n")

# Anchor: echo "Özet:" satırını bul
insert_idx = None
for i, line in enumerate(lines):
    if re.search(r'^\s*echo\s+["\']Özet:\s*["\']\s*$', line):
        insert_idx = i
        break

# Fallback: içinde Özet: geçen ilk satır
if insert_idx is None:
    for i, line in enumerate(lines):
        if "Özet:" in line:
            insert_idx = i
            break

if insert_idx is None:
    print("❌ Anchor bulunamadı: Özet: yok.")
    sys.exit(1)

addon = r'''
echo
echo "==> 5) Listing create -> link -> verify"

# Match sonrası consultantId set olmalı; default seed id:
ACTOR_ID="consultant_seed_1"

echo "==> Listing create"
CREATE_RESP="$(curl -sS -X POST "$BASE_URL/listings" \
  -H "Content-Type: application/json" \
  -H "x-user-id: $ACTOR_ID" \
  -d '{"title":"Test Listing","city":"Konya","district":"Selçuklu","type":"SATILIK","rooms":"2+1"}'
)"
if [[ "$HAS_JQ" -eq 1 ]]; then echo "$CREATE_RESP" | jq; else echo "$CREATE_RESP"; fi

LISTING_ID="$(echo "$CREATE_RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("id",""))')"
if [ -z "${LISTING_ID:-}" ]; then
  echo "❌ LISTING_ID parse edilemedi."
  exit 1
fi
echo "✅ LISTING_ID=$LISTING_ID"
echo

echo "==> Link listing to deal"
LINK_RESP="$(curl -sS -X POST "$BASE_URL/deals/$DEAL_ID/link-listing/$LISTING_ID" \
  -H "Content-Type: application/json" \
  -H "x-user-id: $ACTOR_ID"
)"
if [[ "$HAS_JQ" -eq 1 ]]; then echo "$LINK_RESP" | jq; else echo "$LINK_RESP"; fi
echo

echo "==> Verify deal"
curl -sS "$BASE_URL/deals/$DEAL_ID" | ( [[ "$HAS_JQ" -eq 1 ]] && jq || cat )
echo
echo "==> Verify listing"
curl -sS "$BASE_URL/listings/$LISTING_ID" -H "x-user-id: $ACTOR_ID" | ( [[ "$HAS_JQ" -eq 1 ]] && jq || cat )
echo
'''

new_lines = lines[:insert_idx] + addon.strip("\n").split("\n") + [""] + lines[insert_idx:]
patched = "\n".join(new_lines)

# restore CRLF if original had it
if "\r\n" in txt:
    patched = patched.replace("\n","\r\n")

bak = target.with_suffix(f".sh.bak.{datetime.now().strftime('%Y%m%d-%H%M%S')}")
bak.write_text(txt, encoding="utf-8")
target.write_text(patched, encoding="utf-8")

print(f"✅ Patch OK: {target}")
print(f"✅ Backup : {bak}")
PY
