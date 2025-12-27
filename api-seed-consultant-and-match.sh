#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
need() { command -v "$1" >/dev/null 2>&1 || { echo "Eksik komut: $1"; exit 1; }; }
need curl
need python3
need node

echo "==> 0) OpenAPI JSON'u bul"
OPENAPI_TMP="/tmp/openapi.json"
rm -f "$OPENAPI_TMP"

for p in /docs-json /swagger-json /api-json /openapi.json /swagger.json; do
  if curl -fsS "$BASE_URL$p" -o "$OPENAPI_TMP"; then
    echo "✅ OpenAPI bulundu: $BASE_URL$p -> $OPENAPI_TMP"
    break
  else
    echo "nope: $BASE_URL$p"
  fi
done

if [[ ! -s "$OPENAPI_TMP" ]]; then
  echo "❌ OpenAPI JSON bulunamadı. Swagger UI var ama JSON endpoint kapalı olabilir."
  echo "Bu durumda /docs sayfasında Network tab ile JSON path'i buluruz."
  exit 2
fi

echo
echo "==> 1) User/Auth/Admin ile ilgili POST endpoint'leri listele"
python3 - <<'PY'
import json
spec=json.load(open("/tmp/openapi.json"))
paths=spec.get("paths",{})
cands=[]
for path,methods in paths.items():
  for m in methods.keys():
    if m.lower()!="post": 
      continue
    low=path.lower()
    if any(k in low for k in ["user","users","auth","register","admin","signup"]):
      cands.append(path)
print("\n".join(sorted(set(cands))))
PY

echo
echo "==> 2) Muhtemel endpoint'lere consultant create dene"
EMAIL="consultant1@test.local"

# Denenecek body varyasyonları (en yaygın şemalar)
BODIES=(
  "{\"email\":\"$EMAIL\",\"name\":\"Consultant One\",\"role\":\"CONSULTANT\",\"password\":\"Test1234!\"}"
  "{\"email\":\"$EMAIL\",\"fullName\":\"Consultant One\",\"role\":\"CONSULTANT\",\"password\":\"Test1234!\"}"
  "{\"email\":\"$EMAIL\",\"name\":\"Consultant One\",\"type\":\"CONSULTANT\",\"password\":\"Test1234!\"}"
  "{\"email\":\"$EMAIL\",\"name\":\"Consultant One\",\"role\":\"CONSULTANT\"}"
  "{\"email\":\"$EMAIL\",\"name\":\"Consultant One\"}"
)

# OpenAPI'dan aday path'leri çek
mapfile -t PATHS < <(python3 - <<'PY'
import json
spec=json.load(open("/tmp/openapi.json"))
paths=spec.get("paths",{})
out=[]
for path,methods in paths.items():
  if "post" in {k.lower() for k in methods.keys()}:
    low=path.lower()
    if any(k in low for k in ["auth","register","signup","users","user","admin/users","admin/user"]):
      out.append(path)
print("\n".join(sorted(set(out))))
PY
)

CREATED="NO"
for path in "${PATHS[@]}"; do
  for body in "${BODIES[@]}"; do
    echo "--> POST $path  body=$body"
    RESP="$(curl -sS -X POST "$BASE_URL$path" -H "Content-Type: application/json" -d "$body" || true)"
    echo "resp: $RESP"

    # id veya email dönmüşse başarı say
    if echo "$RESP" | grep -Eq '"id"\s*:\s*"|'"\"$EMAIL\""; then
      echo "✅ Consultant create başarılı görünüyor (path=$path)"
      CREATED="YES"
      break 2
    fi

    # bazı API'ler 409 "already exists" der -> o da OK
    if echo "$RESP" | grep -qi "already"; then
      echo "✅ Zaten var gibi (path=$path)"
      CREATED="YES"
      break 2
    fi
  done
done

echo
if [[ "$CREATED" != "YES" ]]; then
  echo "❌ API üzerinden consultant create edemedim."
  echo "Bunun iki ana nedeni olur:"
  echo "1) Endpoint auth istiyor (JWT)."
  echo "2) Body şeması farklı / ekstra zorunlu alanlar var."
  echo
  echo "Bir sonraki adım: OpenAPI içinden requestBody schema'sını otomatik çıkarıp doğru body'yi üreteceğim."
  exit 3
fi

echo "==> 3) Yeni lead+deal üret ve match dene"
LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{ "initialText": "api-seed consultant + match" }')"
LEAD_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$LEAD_JSON")"
DEAL_JSON="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID")"
DEAL_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$DEAL_JSON")"
echo "DEAL_ID=$DEAL_ID"

MATCH_RESP="$(curl -sS -X POST "$BASE_URL/deals/$DEAL_ID/match" || true)"
echo "Match response: $MATCH_RESP"

echo "✅ DONE"
