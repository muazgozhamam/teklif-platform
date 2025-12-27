#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Eksik komut: $1"; exit 1; }; }
need curl
need python3

json_get() {
  # usage: json_get "$JSON" "id"
  JSON="$1" KEY="$2" python3 - <<'PY'
import os, json
obj = json.loads(os.environ["JSON"])
key = os.environ["KEY"]
print(obj.get(key,""))
PY
}

echo "==> 1) Lead oluştur"
LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" \
  -H "Content-Type: application/json" \
  -d '{ "initialText": "test lead" }')"
echo "Lead response: $LEAD_JSON"

LEAD_ID="$(json_get "$LEAD_JSON" "id")"
if [[ -z "${LEAD_ID:-}" ]]; then
  echo "❌ Lead ID parse edilemedi."
  exit 1
fi
echo "LEAD_ID=$LEAD_ID"
echo

echo "==> 2) Deal'i leadId ile al (var mı?)"
DEAL_JSON="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID" || true)"
echo "Deal response: $DEAL_JSON"
echo

# 404 ise deal create dene (endpoint tasarımı böyle olabilir)
if echo "$DEAL_JSON" | grep -q '"statusCode":404'; then
  echo "==> 2b) Deal yok görünüyor. Deal create deniyorum (POST /deals {leadId})"
  CREATE_DEAL_JSON="$(curl -sS -X POST "$BASE_URL/deals" \
    -H "Content-Type: application/json" \
    -d "{\"leadId\":\"$LEAD_ID\"}" || true)"
  echo "Create deal response: $CREATE_DEAL_JSON"
  echo

  echo "==> 2c) Tekrar deal'i leadId ile al"
  DEAL_JSON="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID" || true)"
  echo "Deal response (retry): $DEAL_JSON"
  echo
fi

# Deal id'yi çek
DEAL_ID=""
if echo "$DEAL_JSON" | python3 -c "import json,sys; json.loads(sys.stdin.read())" >/dev/null 2>&1; then
  DEAL_ID="$(json_get "$DEAL_JSON" "id")"
fi

if [[ -z "${DEAL_ID:-}" ]]; then
  echo "❌ Deal ID bulunamadı."
  echo "Bu durumda büyük olasılık:"
  echo "- /leads otomatik deal oluşturmuyor ve POST /deals body şeması leadId’den farklı."
  echo
  echo "Şimdi OpenAPI'dan deal create endpoint/body şemasını çıkaracağız."
  exit 2
fi

echo "DEAL_ID=$DEAL_ID"
echo

echo "==> 3) Deal match et"
MATCH_JSON="$(curl -sS -X POST "$BASE_URL/deals/$DEAL_ID/match" || true)"
echo "Match response: $MATCH_JSON"
echo
echo "✅ E2E akış tamam."
