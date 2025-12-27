#!/usr/bin/env bash
# ÇALIŞILACAK KÖK: ~/Desktop/teklif-platform
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$ROOT/dev-start-and-e2e.sh"

python3 - <<'PY'
from pathlib import Path
from datetime import datetime
import re, sys

root = Path.cwd()
target = root / "dev-start-and-e2e.sh"
txt = target.read_text(encoding="utf-8", errors="replace")

# normalize for matching
norm = txt.replace("\r\n","\n").replace("\r","\n")

start_marker = 'echo "==> 5) Listing create -> link -> verify"'
if start_marker not in norm:
    print("❌ Step-5 marker bulunamadı. Önce FINAL patch uygulanmış olmalı.")
    sys.exit(1)

# find block start
start_idx = norm.index(start_marker)

# block end: Özet: anchor'ına kadar (Özet satırı dahil değil)
m_end = re.search(r'(?m)^\s*echo\s+["\']Özet:\s*["\']\s*$', norm)
if not m_end:
    print("❌ 'Özet:' anchor bulunamadı.")
    sys.exit(1)
end_idx = m_end.start()

prefix = norm[:start_idx]
suffix = norm[end_idx:]  # Özet: ve sonrası korunacak

new_block = r'''
echo
echo "==> 5) Listing create -> link -> verify"

# Deal'den consultantId çek; listing işlemlerini o user olarak yapacağız.
DEAL_AFTER_MATCH="$(curl -sS "$BASE_URL/deals/$DEAL_ID")"
ACTOR_ID="$(echo "$DEAL_AFTER_MATCH" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("consultantId",""))')"

if [ -z "${ACTOR_ID:-}" ]; then
  echo "⚠️ consultantId boş (match başarısız/çalışmadı). Listing adımı atlanıyor."
else
  echo "✅ ACTOR_ID=$ACTOR_ID"
  echo

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
fi

'''

patched = prefix.rstrip("\n") + "\n" + new_block.strip("\n") + "\n\n" + suffix.lstrip("\n")

# restore CRLF if original used it
if "\r\n" in txt:
    patched = patched.replace("\n", "\r\n")

bak = target.with_suffix(f".sh.bak.{datetime.now().strftime('%Y%m%d-%H%M%S')}")
bak.write_text(txt, encoding="utf-8")
target.write_text(patched, encoding="utf-8")

print(f"✅ Patch v3 OK: {target}")
print(f"✅ Backup     : {bak}")
PY
