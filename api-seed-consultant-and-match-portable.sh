#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
ADMIN_EMAIL="${ADMIN_EMAIL:-}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
CONSULTANT_EMAIL="${CONSULTANT_EMAIL:-consultant1@test.local}"
CONSULTANT_PASSWORD="${CONSULTANT_PASSWORD:-Test1234!}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Eksik komut: $1"; exit 1; }; }
need curl
need python3
need node

if [[ -z "$ADMIN_EMAIL" || -z "$ADMIN_PASSWORD" ]]; then
  echo "❌ ADMIN_EMAIL / ADMIN_PASSWORD env set değil."
  echo "Örnek:"
  echo "  export ADMIN_EMAIL=\"...\""
  echo "  export ADMIN_PASSWORD=\"...\""
  exit 2
fi

echo "==> 1) Admin login (token al)"
LOGIN_RESP="$(curl -sS -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" || true)"
echo "login resp: $LOGIN_RESP"

TOKEN="$(python3 - <<'PY'
import json, os, sys
s=os.environ["LOGIN_RESP"]
try:
  obj=json.loads(s)
except Exception:
  print("")
  sys.exit(0)
for k in ["accessToken","access_token","token","jwt"]:
  if isinstance(obj, dict) and k in obj and obj[k]:
    print(obj[k]); sys.exit(0)
# bazen {data:{accessToken:""}} olur
data=obj.get("data") if isinstance(obj, dict) else None
if isinstance(data, dict):
  for k in ["accessToken","access_token","token","jwt"]:
    if k in data and data[k]:
      print(data[k]); sys.exit(0)
print("")
PY
)"

if [[ -z "$TOKEN" ]]; then
  echo "❌ Token parse edilemedi. /auth/login response formatı farklı veya login başarısız."
  exit 3
fi
echo "TOKEN OK"
echo

echo "==> 2) Consultant oluştur (POST /admin/users)"
CREATE_BODY="{\"email\":\"$CONSULTANT_EMAIL\",\"name\":\"Consultant One\",\"role\":\"CONSULTANT\",\"password\":\"$CONSULTANT_PASSWORD\"}"

CREATE_RESP="$(curl -sS -X POST "$BASE_URL/admin/users" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "$CREATE_BODY" || true)"
echo "create resp: $CREATE_RESP"
echo

# 409 / already exists ise de OK kabul edelim
if echo "$CREATE_RESP" | grep -qiE '"id"\s*:|already|exists|409'; then
  echo "✅ Consultant create: OK (oluştu veya zaten vardı)"
else
  echo "❌ Consultant create başarısız görünüyor."
  echo "Muhtemelen body şeması farklı (required fields) veya role enum farklı."
  exit 4
fi

echo
echo "==> 3) Yeni lead+deal üret ve match dene"
LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{ "initialText": "portable seed consultant + match" }')"
LEAD_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$LEAD_JSON")"
DEAL_JSON="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID")"
DEAL_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$DEAL_JSON")"
echo "DEAL_ID=$DEAL_ID"

MATCH_RESP="$(curl -sS -X POST "$BASE_URL/deals/$DEAL_ID/match" || true)"
echo "Match response: $MATCH_RESP"
echo
echo "✅ DONE"
