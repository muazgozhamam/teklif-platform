#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE_URL:-http://localhost:3001}"
CURL="curl -sS --connect-timeout 2 --max-time 8"

echo "==> 0) Health"
$CURL "$BASE/health" || true
echo

echo "==> 1) Create lead"
LEAD="$($CURL -X POST "$BASE/leads" -H "Content-Type: application/json" -d '{"initialText":"doctor wizard+match"}')"
LEAD_ID="$(echo "$LEAD" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")"
echo "leadId=$LEAD_ID"
echo

echo "==> 2) Wizard loop (key/answer) max 10 steps"
for step in $(seq 1 10); do
  Q="$($CURL "$BASE/leads/$LEAD_ID/next")"
  echo "Q$step: $Q" | python3 -c "import sys,json; print(json.dumps(json.loads(sys.stdin.read().split(': ',1)[1]), ensure_ascii=False))" || true

  DONE="$(echo "$Q" | python3 -c "import sys,json; j=json.load(sys.stdin); print('1' if j.get('done') else '0')")"
  KEY="$(echo "$Q"  | python3 -c "import sys,json; j=json.load(sys.stdin); print(j.get('key') or '')")"

  if [[ "$DONE" == "1" || -z "$KEY" ]]; then
    echo "wizard done"
    break
  fi

  case "$KEY" in
    city) ans="Konya" ;;
    district) ans="Meram" ;;
    type) ans="SATILIK" ;;
    rooms) ans="2+1" ;;
    *) ans="x" ;;
  esac

  echo "-> answer: key=$KEY answer=$ans"
  A="$($CURL -X POST "$BASE/leads/$LEAD_ID/answer" -H "Content-Type: application/json" -d "{\"key\":\"$KEY\",\"answer\":\"$ans\"}")"
  # Eğer hata dönerse göster ve çık
  if echo "$A" | grep -q '"statusCode"'; then
    echo "❌ answer error:"
    echo "$A" | python3 -m json.tool || echo "$A"
    exit 1
  fi
done

echo
echo "==> 3) Deal by lead"
DEAL="$($CURL "$BASE/deals/by-lead/$LEAD_ID")"
echo "$DEAL" | python3 -m json.tool
DEAL_ID="$(echo "$DEAL" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")"
STATUS="$(echo "$DEAL" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status'))")"
echo "dealId=$DEAL_ID status=$STATUS"
echo

echo "==> 4) Match deal"
MATCH="$($CURL -X POST "$BASE/deals/$DEAL_ID/match")"
echo "$MATCH" | python3 -m json.tool || echo "$MATCH"
echo
echo "✅ DONE"
