#!/usr/bin/env bash
set -euo pipefail

API_BASE="${API_BASE:-http://localhost:3001}"

echo "==> 1) Health kontrol: $API_BASE/health"
if curl -fsS "$API_BASE/health" >/dev/null 2>&1; then
  echo "✅ HEALTH OK"
else
  echo "❌ HEALTH FAIL: $API_BASE/health"
  echo "   Muhtemel neden: API kapalı veya port farklı."
  echo "   Port 3001 dinliyor mu?"
  lsof -nP -iTCP:3001 -sTCP:LISTEN || true
  exit 1
fi

echo
echo "==> 2) OpenAPI JSON path denemeleri"
CANDIDATES=(
  "/docs-json"
  "/api-json"
  "/swagger-json"
  "/swagger/v1/swagger.json"
  "/openapi.json"
  "/docs/swagger.json"
)

FOUND=""
for p in "${CANDIDATES[@]}"; do
  if curl -fsS "$API_BASE$p" >/dev/null 2>&1; then
    FOUND="$p"
    break
  fi
done

if [[ -z "$FOUND" ]]; then
  echo "❌ OpenAPI JSON bulunamadı."
  echo "   Denenen path'ler:"
  printf "   - %s\n" "${CANDIDATES[@]}"
  echo
  echo "   İpucu: Swagger UI açıksa, şunları kontrol et:"
  echo "     curl -i $API_BASE/docs"
  echo "     curl -i $API_BASE/swagger"
  exit 2
fi

echo "✅ OpenAPI JSON bulundu: $API_BASE$FOUND"
echo
echo "==> 3) İlk 3 satırı göster (doğrulama)"
curl -fsS "$API_BASE$FOUND" | head -n 3
