#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
ADMIN_EMAIL="${ADMIN_EMAIL:-}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Eksik komut: $1"; exit 1; }; }
need curl
need python3

echo "==> 0) OpenAPI çek"
OPENAPI="/tmp/openapi.json"
curl -fsS "$BASE_URL/docs-json" -o "$OPENAPI"
echo "✅ $BASE_URL/docs-json -> $OPENAPI"
echo

echo "==> 1) /auth/login requestBody şemasını göster"
python3 - <<'PY'
import json
spec=json.load(open("/tmp/openapi.json"))
op=spec["paths"].get("/auth/login",{}).get("post",{})
rb=op.get("requestBody",{})
print(json.dumps(rb, indent=2, ensure_ascii=False))
PY
echo

if [[ -z "$ADMIN_EMAIL" || -z "$ADMIN_PASSWORD" ]]; then
  echo "❌ ADMIN_EMAIL / ADMIN_PASSWORD set değil."
  echo "Örn:"
  echo "  export ADMIN_EMAIL=\"gercek-admin@mail.com\""
  echo "  export ADMIN_PASSWORD=\"gercekSifre\""
  exit 2
fi

if [[ "$ADMIN_EMAIL" == *"senin-admin"* || "$ADMIN_PASSWORD" == *"senin-admin"* ]]; then
  echo "❌ Placeholder değer girmişsin. Gerçek admin email/şifre lazım."
  exit 3
fi

echo "==> 2) Login dene"
LOGIN_RESP="$(curl -sS -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" || true)"
echo "login resp: $LOGIN_RESP"
echo

TOKEN="$(printf '%s' "$LOGIN_RESP" | python3 - <<'PY'
import sys, json
s=sys.stdin.read().strip()
try:
  obj=json.loads(s)
except Exception:
  print(""); sys.exit(0)

def pick(d):
  if not isinstance(d, dict): return ""
  for k in ["accessToken","access_token","token","jwt"]:
    v=d.get(k)
    if isinstance(v,str) and v.strip():
      return v.strip()
  return ""

t=pick(obj) or pick(obj.get("data") if isinstance(obj,dict) else None)
print(t)
PY
)"

if [[ -n "$TOKEN" ]]; then
  echo "✅ TOKEN bulundu"
  echo "TOKEN (ilk 20 char): ${TOKEN:0:20}..."
  exit 0
fi

echo "❌ Token alınamadı. Büyük ihtimalle 401 veya response formatı farklı."
echo

echo "==> 3) Repoda default admin / seed credential ara"
# Hedefli aramalar (çok gürültü yapmaması için kısıtlı)
rg -n --hidden --no-ignore-vcs -S \
  "(admin@|ADMIN_EMAIL|ADMIN_PASSWORD|default admin|seed.*admin|password.*admin|email.*admin|Test1234|admin123|superadmin)" \
  apps/api prisma package.json pnpm-lock.yaml 2>/dev/null | head -n 120 || true

echo
echo "==> 4) .env dosyalarında admin ipucu ara"
for f in apps/api/.env apps/api/.env.local .env .env.local; do
  if [[ -f "$f" ]]; then
    echo "--- $f ---"
    rg -n -S "(ADMIN|admin|PASSWORD|EMAIL)" "$f" || true
  fi
done

echo
echo "Bitti. Eğer yukarıda admin email/şifre veya seed ipucu çıktıysa, onları kullanıp tekrar /auth/login dene."
