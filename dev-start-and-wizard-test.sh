#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
API_DIR="$ROOT_DIR/apps/api"
BASE_URL="http://localhost:3001"
LOG="/tmp/teklif-api-dev.log"
PIDFILE="/tmp/teklif-api-dev.pid"

say() { echo; echo "==> $*"; }

die() {
  echo
  echo "❌ $*"
  echo
  echo "Son 120 satır log ($LOG):"
  tail -n 120 "$LOG" 2>/dev/null || true
  exit 1
}

say "0) Konum kontrol"
[[ -d "$API_DIR" ]] || die "API dizini yok: $API_DIR"
echo "ROOT=$ROOT_DIR"
echo "API =$API_DIR"

say "1) (Opsiyonel) Eski server varsa kapat"
if [[ -f "$PIDFILE" ]]; then
  OLD_PID="$(cat "$PIDFILE" || true)"
  if [[ -n "${OLD_PID:-}" ]] && ps -p "$OLD_PID" >/dev/null 2>&1; then
    echo "Eski PID bulundu: $OLD_PID -> kill"
    kill "$OLD_PID" || true
    sleep 1
  fi
  rm -f "$PIDFILE" || true
fi

say "2) Prisma generate + build (apps/api)"
pushd "$API_DIR" >/dev/null
pnpm -s prisma generate --schema prisma/schema.prisma >/dev/null
pnpm -s build
popd >/dev/null
echo "✅ build OK"

say "3) API başlat (background) + health bekle"
# start:dev watch modunda olur; bunu background'a alıyoruz.
# Log: /tmp/teklif-api-dev.log
( cd "$API_DIR" && pnpm -s start:dev ) >"$LOG" 2>&1 &
PID=$!
echo "$PID" > "$PIDFILE"
echo "PID=$PID"
echo "LOG=$LOG"

# Health bekle
OK=0
for i in $(seq 1 60); do
  if curl -sS "$BASE_URL/health" >/dev/null 2>&1; then
    OK=1
    break
  fi
  sleep 0.5
done
[[ "$OK" -eq 1 ]] || die "API 3001'de ayağa kalkmadı (health gelmedi)."

echo "✅ health OK"
curl -sS "$BASE_URL/health" || true
echo

say "4) Wizard testi (Lead -> next-question -> answer -> next-question)"
HAS_JQ=0
command -v jq >/dev/null 2>&1 && HAS_JQ=1

LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" \
  -H "Content-Type: application/json" \
  -d '{ "initialText": "wizard test" }')"

if [[ "$HAS_JQ" -eq 1 ]]; then
  echo "$LEAD_JSON" | jq
else
  echo "$LEAD_JSON"
fi

LEAD_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$LEAD_JSON")"
[[ -n "${LEAD_ID:-}" ]] || die "Lead ID alınamadı."
echo "LEAD_ID=$LEAD_ID"

echo
echo "next-question:"
curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/next-question" | (jq || cat)

echo
echo "answer=Konya:"
curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/answer" \
  -H "Content-Type: application/json" \
  -d '{ "answer": "Konya" }' | (jq || cat)

echo
echo "next-question (2):"
curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/next-question" | (jq || cat)

say "✅ DONE"
echo "Not: API background çalışıyor. Durdurmak için:"
echo "  kill $(cat "$PIDFILE")"
