#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"

say(){ echo; echo "==> $*"; }
die(){ echo; echo "❌ $*"; exit 1; }

HAS_JQ=0
command -v jq >/dev/null 2>&1 && HAS_JQ=1

# Basit JSON field okuyucu (jq yoksa node ile)
json_get () {
  local key="$1"
  local json="$2"
  node -p "(() => { const o=JSON.parse(process.argv[1]); return (o && o['$key']!=null) ? o['$key'] : '' })()" "$json"
}

answer_for_field () {
  local field="$1"
  case "$field" in
    city) echo "Konya" ;;
    district) echo "Selçuklu" ;;
    type) echo "SATILIK" ;;   # senin modelin enum isterse burada güncelleriz
    rooms) echo "2+1" ;;      # senin modelin enum isterse burada güncelleriz
    *) echo "" ;;
  esac
}

say "0) Health kontrol"
curl -sS "$BASE_URL/health" >/dev/null || die "API yok (health). Önce dev-start-and-wizard-test.sh ile server başlat."
echo "✅ health OK"

say "1) Lead oluştur"
LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" \
  -H "Content-Type: application/json" \
  -d '{ "initialText": "wizard complete + match test" }')"

if [[ "$HAS_JQ" -eq 1 ]]; then echo "$LEAD_JSON" | jq; else echo "$LEAD_JSON"; fi

LEAD_ID="$(json_get id "$LEAD_JSON")"
[[ -n "$LEAD_ID" ]] || die "Lead ID alınamadı."
echo "LEAD_ID=$LEAD_ID"

say "2) Wizard döngüsü (next-question -> answer) done olana kadar"
DEAL_ID=""

for step in $(seq 1 10); do
  Q_JSON="$(curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/next-question")"
  if [[ "$HAS_JQ" -eq 1 ]]; then echo "$Q_JSON" | jq; else echo "$Q_JSON"; fi

  DONE="$(json_get done "$Q_JSON")"
  if [[ "$DONE" == "true" ]]; then
    echo "✅ Wizard done=true"
    break
  fi

  FIELD="$(json_get field "$Q_JSON")"
  DEAL_ID="$(json_get dealId "$Q_JSON")"
  [[ -n "$FIELD" ]] || die "field gelmedi."
  [[ -n "$DEAL_ID" ]] || die "dealId gelmedi."

  ANS="$(answer_for_field "$FIELD")"
  [[ -n "$ANS" ]] || die "Bu field için otomatik cevap yok: $FIELD"

  echo
  echo "answer field=$FIELD -> '$ANS'"

  A_JSON="$(curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/answer" \
    -H "Content-Type: application/json" \
    -d "{\"answer\":\"$ANS\"}")"

  if [[ "$HAS_JQ" -eq 1 ]]; then echo "$A_JSON" | jq; else echo "$A_JSON"; fi

  # bazı implementasyonlarda answer response içinde next döner; döngü yine de next-question ile devam eder
done

[[ -n "$DEAL_ID" ]] || die "DEAL_ID oluşmadı."

say "3) Deal'i çek (son hali)"
DEAL_JSON="$(curl -sS "$BASE_URL/deals/$DEAL_ID")"
if [[ "$HAS_JQ" -eq 1 ]]; then echo "$DEAL_JSON" | jq; else echo "$DEAL_JSON"; fi

say "4) Match (deal -> consultant ata)"
MATCH_JSON="$(curl -sS -X POST "$BASE_URL/deals/$DEAL_ID/match")"
if [[ "$HAS_JQ" -eq 1 ]]; then echo "$MATCH_JSON" | jq; else echo "$MATCH_JSON"; fi

say "✅ DONE"
echo "Özet:"
echo "- LEAD_ID=$LEAD_ID"
echo "- DEAL_ID=$DEAL_ID"
