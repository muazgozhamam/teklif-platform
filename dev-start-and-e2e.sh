#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Desktop/teklif-platform"
API_DIR="$ROOT/apps/api"
BASE_URL="http://localhost:3001"
LOG="/tmp/teklif-api-dev.log"
PIDFILE="/tmp/teklif-api-dev.pid"

need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ '$1' yok"; exit 1; }; }
need curl

HAS_JQ=0
if command -v jq >/dev/null 2>&1; then HAS_JQ=1; fi

echo "==> 0) Konum kontrol"
echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"
echo "LOG=$LOG"
echo "PIDFILE=$PIDFILE"
echo

[[ -d "$API_DIR" ]] || { echo "❌ API_DIR yok: $API_DIR"; exit 1; }

echo "==> 1) Eski server varsa kapat (PIDFILE / port 3001)"
if [[ -f "$PIDFILE" ]]; then
  OLD_PID="$(cat "$PIDFILE" || true)"
  if [[ -n "${OLD_PID:-}" ]] && kill -0 "$OLD_PID" 2>/dev/null; then
    echo "-> kill $OLD_PID"
    kill "$OLD_PID" 2>/dev/null || true
    sleep 1
  fi
  rm -f "$PIDFILE" || true
fi

# 3001 dinleyen varsa kapat (macOS)
if command -v lsof >/dev/null 2>&1; then
  PIDS="$(lsof -ti tcp:3001 || true)"
  if [[ -n "${PIDS:-}" ]]; then
    echo "-> 3001 portunda süreç(ler) var: $PIDS"
    for p in $PIDS; do
      kill "$p" 2>/dev/null || true
    done
    sleep 1
  fi
fi
echo "✅ temiz"
echo

echo "==> 2) Prisma generate + build (apps/api)"
cd "$API_DIR"
pnpm -s prisma generate --schema prisma/schema.prisma
pnpm -s build
echo "✅ build OK"
echo

echo "==> 3) API başlat (background) + health bekle"
# Not: start:dev kullanıyoruz; sende script adı farklıysa (ör: dev) burada değiştir.
# Çoğu Nest projesinde start:dev var.
nohup pnpm -s start:dev >"$LOG" 2>&1 & echo $! >"$PIDFILE"
PID="$(cat "$PIDFILE")"
echo "PID=$PID"
echo "LOG=$LOG"
echo

# health wait
OK=0
for i in {1..40}; do
  if curl -fsS "$BASE_URL/health" >/dev/null 2>&1; then OK=1; break; fi
  sleep 0.5
done
if [[ "$OK" -ne 1 ]]; then
  echo "❌ Health gelmedi: $BASE_URL/health"
  echo "Son log satırları:"
  tail -n 120 "$LOG" || true
  exit 1
fi

echo "✅ health OK"
curl -sS "$BASE_URL/health" | cat
echo

echo "==> 4) E2E: lead -> wizard complete -> status -> match"
LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{ "initialText": "dev-start-and-e2e" }')"
if [[ "$HAS_JQ" -eq 1 ]]; then echo "$LEAD_JSON" | jq; else echo "$LEAD_JSON"; fi
LEAD_ID="$(echo "$LEAD_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")"
# Wizard loop: next-question -> answer (max 10 steps)
DEAL_ID=""
LAST_NQ=""

for i in $(seq 1 10); do
  NQ="$(curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/next-question")"
  LAST_NQ="$NQ"

  # dealId ilk seferde set edelim
  if [ -z "${DEAL_ID:-}" ]; then
    DEAL_ID="$(echo "$NQ" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("dealId",""))')"
  fi

  DONE="$(echo "$NQ" | python3 -c 'import sys,json; print(str(json.load(sys.stdin).get("done", False)).lower())')"
  if [ "$DONE" = "true" ]; then
    break
  fi

  KEY="$(echo "$NQ" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("key",""))')"

  ANSWER=""
  case "$KEY" in
    city) ANSWER="Konya" ;;
    district) ANSWER="Selçuklu" ;;
    type) ANSWER="SALE" ;;   # SATILIK -> SALE (listing tarafıyla uyumlu)
    rooms) ANSWER="2+1" ;;
    *) ANSWER="Konya" ;;
  esac

  # Hem key+answer gönderiyoruz (API key'i görmezden gelirse sorun olmaz; isterse de tamamdır)
  curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/answer" \
    -H "Content-Type: application/json" \
    -d "{\"key\":\"$KEY\",\"answer\":\"$ANSWER\"}" >/dev/null
done

if [ -z "${DEAL_ID:-}" ]; then
  echo "❌ DEAL_ID alınamadı. Last next-question response:"
  echo "$LAST_NQ" | cat
  exit 1
fi

DEAL_JSON="$(curl -sS "$BASE_URL/deals/$DEAL_ID")"
if [[ "$HAS_JQ" -eq 1 ]]; then echo "$DEAL_JSON" | jq; else echo "$DEAL_JSON"; fi
STATUS="$(echo "$DEAL_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status'))")"
echo "STATUS=$STATUS"
echo

if [[ "$STATUS" == "READY_FOR_MATCHING" ]]; then
  echo "-> match()"
  MATCH_JSON="$(curl -sS -X POST "$BASE_URL/deals/$DEAL_ID/match")"
  if [[ "$HAS_JQ" -eq 1 ]]; then echo "$MATCH_JSON" | jq; else echo "$MATCH_JSON"; fi
else
  echo "⚠️ Status READY_FOR_MATCHING değil; match guard'ı test etmek için önce status akışını düzeltmemiz gerekir."
fi

echo
echo
echo
echo "==> 5) Listing create -> link -> verify"

# Deal'den consultantId çek; listing işlemlerini o user olarak yapacağız.
DEAL_AFTER_MATCH="$(curl -sS "$BASE_URL/deals/$DEAL_ID")"
ACTOR_ID="$(echo "$DEAL_AFTER_MATCH" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("consultantId",""))')"

if [ -z "${ACTOR_ID:-}" ]; then
  echo "⚠️ consultantId boş (match başarısız/çalışmadı). Listing adımı atlanıyor."
else
  echo "✅ ACTOR_ID=$ACTOR_ID"

  # ACTOR_ID can be empty/null/None depending on match flow; fallback to seeded consultant for E2E.
  if [ -z "${ACTOR_ID:-}" ] || [ "${ACTOR_ID}" = "null" ] || [ "${ACTOR_ID}" = "None" ]; then
    ACTOR_ID="consultant_seed_1"
    echo "INFO: ACTOR_ID fallback -> $ACTOR_ID"
  fi
  echo

  echo "==> Listing create"
  CREATE_RESP="$(curl -sS -X POST "$BASE_URL/listings" \
    -H "Content-Type: application/json" \
    -H "x-user-id: $ACTOR_ID" \
    -d '{"title":"Test Listing - ","city":"Konya","district":"Selçuklu","type":"SALE","rooms":"2+1","price":1234567}'
  )"
  if [[ "$HAS_JQ" -eq 1 ]]; then echo "$CREATE_RESP" | jq; else echo "$CREATE_RESP"; fi

  LISTING_ID="$(echo "$CREATE_RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("id",""))')"

echo
echo
echo "==> Publish listing (so dashboard PUBLISHED feed includes it)"
API_BASE="${BASE_URL:-http://localhost:3001}"

# 1) Try common publish endpoints (best-effort). If none exist, try PATCH update status.
PUB_OK=0

# Try: PATCH /listings/:id/publish
if curl -sS -X PATCH "$API_BASE/listings/$LISTING_ID/publish" \
  -H "Content-Type: application/json" >/tmp/.tmp_publish_resp.json 2>/dev/null; then
  # If endpoint exists, it should not return 404 HTML. We'll just treat non-404 as success later.
  if ! grep -q '"statusCode":404' /tmp/.tmp_publish_resp.json 2>/dev/null; then
    PUB_OK=1
  fi
fi

# Try: POST /listings/:id/publish
if [ "$PUB_OK" -eq 0 ]; then
  if curl -sS -X POST "$API_BASE/listings/$LISTING_ID/publish" \
    -H "Content-Type: application/json" >/tmp/.tmp_publish_resp.json 2>/dev/null; then
    if ! grep -q '"statusCode":404' /tmp/.tmp_publish_resp.json 2>/dev/null; then
      PUB_OK=1
    fi
  fi
fi

# Try: PATCH /listings/:id with {"status":"PUBLISHED"}
if [ "$PUB_OK" -eq 0 ]; then
  if curl -sS -X PATCH "$API_BASE/listings/$LISTING_ID" \
    -H "Content-Type: application/json" \
    -d '{"status":"PUBLISHED"}' >/tmp/.tmp_publish_resp.json 2>/dev/null; then
    if ! grep -q '"statusCode":404' /tmp/.tmp_publish_resp.json 2>/dev/null; then
      PUB_OK=1
    fi
  fi
fi

# 2) Verify via API list filter that listing shows up in PUBLISHED feed
echo "==> Verify listing appears in /listings?status=PUBLISHED"
VERIFY_OK=0
for i in $(seq 1 20); do
  if curl -sS "$API_BASE/listings?status=PUBLISHED" | grep -q "$LISTING_ID"; then
    VERIFY_OK=1
    break
  fi
  sleep 0.25
done

if [ "$VERIFY_OK" -eq 1 ]; then
  echo "✅ Listing is in PUBLISHED feed: $LISTING_ID"
else
  echo "❌ Could not confirm listing in PUBLISHED feed: $LISTING_ID"
  echo "   - Last publish response (if any):"
  cat /tmp/.tmp_publish_resp.json 2>/dev/null || true
  echo
  echo "   - PUBLISHED feed sample:"
  curl -sS "$API_BASE/listings?status=PUBLISHED" | head -c 1200 || true
  echo
  exit 1
fi

echo "==> [142] DASHBOARD /listings HTML assert (listing id should appear in SSR HTML)"
DASH_PORT="${DASH_PORT:-3002}"
DASH_BASE="${DASH_BASE:-http://localhost:${DASH_PORT}}"
DASH_LISTINGS_URL="${DASH_BASE}/listings"

# /listings HTML’i çek
FOUND=0
for i in $(seq 1 40); do
  HTML="$(curl -sS "$DASH_LISTINGS_URL" || true)"
  if echo "$HTML" | grep -q "$LISTING_ID"; then
    FOUND=1
    break
  fi
  sleep 0.5
done

# Assert: ID HTML içinde görünmeli (data attr / gizli marker / plain text)
if echo "$HTML" | grep -q "$LISTING_ID"; then
  echo "✅ [142] PASS: Listing id found in dashboard HTML: $LISTING_ID"
else
  echo "❌ [142] FAIL: Listing id NOT found in dashboard HTML"
  echo "   - URL: $DASH_LISTINGS_URL"
  echo "   - Expected to find LISTING_ID=$LISTING_ID in HTML"
  echo "   - First 120 lines of HTML:"
  echo "$HTML" | sed -n '1,120p'
  exit 1
fi

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
  curl -sS "$BASE_URL/deals/$DEAL_ID" | cat
  echo
  echo "==> Verify listing"
  curl -sS "$BASE_URL/listings/$LISTING_ID" -H "x-user-id: $ACTOR_ID" | cat
  echo
fi

echo "Özet:"
echo "- LEAD_ID=$LEAD_ID"
echo "- DEAL_ID=$DEAL_ID"
echo "- STATUS=$STATUS"
echo
echo "Durdurmak için:"
echo "  kill $PID"
