#!/usr/bin/env bash
set -euo pipefail

BASE="http://localhost:3001"
LOG=".tmp-api-dist.log"

echo "==> 1) Build"
pnpm -s build

echo
echo "==> 2) 3001 portunu boşalt (varsa kill)"
PIDS="$(lsof -nP -t -iTCP:3001 -sTCP:LISTEN || true)"
if [ -n "${PIDS}" ]; then
  echo "   - Killing PID(s): ${PIDS}"
  kill -9 ${PIDS} || true
fi

echo
echo "==> 3) dist'ten API'yi BACKGROUND başlat"
rm -f "$LOG"
PORT=3001 node dist/src/main.js >"$LOG" 2>&1 &
API_PID=$!
echo "   - API_PID=$API_PID"
echo "   - Log: $LOG"
echo "   NOT: API background çalışır; bu terminal BLOKLAMAZ."
echo "   Kapatmak için: kill $API_PID"

echo
echo "==> 4) Health bekle (max 8sn)"
ok=0
for i in 1 2 3 4 5 6 7 8; do
  CODE="$(curl -s -o /dev/null -w "%{http_code}" "$BASE/health" || true)"
  if [ "$CODE" = "200" ]; then ok=1; break; fi
  sleep 1
done

if [ "$ok" != "1" ]; then
  echo "HATA: API ayağa kalkmadı."
  echo "Log (son 160 satır):"
  tail -n 160 "$LOG" || true
  echo "Kapat: kill $API_PID"
  exit 1
fi
echo "   OK"

echo
echo "==> 5) E2E: Lead create -> Deal by lead -> Advance QUESTIONS_COMPLETED"
LEAD_JSON="$(curl -fsS -X POST "$BASE/leads" -H "Content-Type: application/json" -d '{"initialText":"E2E advance test"}')"
LEAD_ID="$(node -e 'const j=JSON.parse(process.argv[1]); process.stdout.write(j.id)' "$LEAD_JSON")"
echo "   LEAD_ID=$LEAD_ID"

DEAL_JSON="$(curl -fsS "$BASE/deals/by-lead/$LEAD_ID")"
DEAL_ID="$(node -e 'const j=JSON.parse(process.argv[1]); process.stdout.write((j.deal||j).id)' "$DEAL_JSON")"
echo "   DEAL_ID=$DEAL_ID"
echo "   Deal: $DEAL_JSON"

ADV_JSON="$(curl -fsS -X POST "$BASE/deals/$DEAL_ID/advance" -H "Content-Type: application/json" -d '{"event":"QUESTIONS_COMPLETED"}')"
echo "   Advance: $ADV_JSON"

echo
echo "==> DONE"
echo "API background çalışıyor. Kapatmak için: kill $API_PID"
