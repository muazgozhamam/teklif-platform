#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
echo "==> BASE_URL=$BASE_URL"

# --- helpers
json_get() { node -e 'const fs=require("fs"); const j=JSON.parse(fs.readFileSync(0,"utf8")); const p=process.argv[1]; console.log((j && j[p])||"");' "$1"; }
http_code() { curl -s -o /dev/null -w "%{http_code}" "$@"; }

deal_json() { curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID"; }
deal_status() { deal_json | node -e 'const fs=require("fs"); const j=JSON.parse(fs.readFileSync(0,"utf8")); process.stdout.write(j.status||"");'; }
deal_id() { deal_json | node -e 'const fs=require("fs"); const j=JSON.parse(fs.readFileSync(0,"utf8")); process.stdout.write(j.id||"");'; }

post_wizard_answer() {
  local field="$1"
  local ans="$2"

  # Aday payload'lar (DTO farklarını yakalamak için)
  local payloads=(
    "{\"field\":\"$field\",\"answer\":\"$ans\"}"
    "{\"key\":\"$field\",\"answer\":\"$ans\"}"
    "{\"field\":\"$field\",\"value\":\"$ans\"}"
    "{\"key\":\"$field\",\"value\":\"$ans\"}"
    "{\"field\":\"$field\",\"text\":\"$ans\"}"
    "{\"key\":\"$field\",\"text\":\"$ans\"}"
    "{\"questionKey\":\"$field\",\"answer\":\"$ans\"}"
    "{\"k\":\"$field\",\"a\":\"$ans\"}"
  )

  local i=0
  for p in "${payloads[@]}"; do
    i=$((i+1))
    local code
    code="$(curl -s -o /tmp/wiz_ans_body.$$ -w "%{http_code}" \
      -X POST "$BASE_URL/leads/$LEAD_ID/wizard/answer" \
      -H "Content-Type: application/json" \
      -d "$p" || true)"

    if [[ "$code" =~ ^2 ]]; then
      echo "✅ wizard/answer accepted (HTTP $code) with payload#$i: $p"
      cat /tmp/wiz_ans_body.$$; echo
      rm -f /tmp/wiz_ans_body.$$
      return 0
    fi
  done

  echo "HATA: wizard/answer hiçbir payload ile 2xx dönmedi."
  echo "Son denenen payload: ${payloads[-1]}"
  echo "Son response body:"
  cat /tmp/wiz_ans_body.$$; echo
  rm -f /tmp/wiz_ans_body.$$
  return 1
}

# --- 1) Create lead
LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{"initialText":"smoke wizard -> match (v2)"}')"
echo "$LEAD_JSON"
LEAD_ID="$(node -e 'const j=JSON.parse(process.argv[1]); console.log(j.id||"")' "$LEAD_JSON")"
[ -n "$LEAD_ID" ] || { echo "HATA: lead id parse edilemedi"; exit 1; }
echo "OK: LEAD_ID=$LEAD_ID"

DEAL_ID="$(deal_id)"
[ -n "$DEAL_ID" ] || { echo "HATA: deal id bulunamadı"; deal_json; exit 1; }
echo "OK: DEAL_ID=$DEAL_ID status=$(deal_status)"

# --- 2) Wizard loop
declare -A ANSWERS
ANSWERS["city"]="Konya"
ANSWERS["district"]="Meram"
ANSWERS["type"]="SATILIK"
ANSWERS["rooms"]="2+1"

echo
echo "==> Wizard Q/A"
for i in 1 2 3 4 5 6 7 8 9 10; do
  Q="$(curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/next-question")"
  echo "Q$i: $Q"

  FIELD="$(echo "$Q" | node -e 'const fs=require("fs"); const j=JSON.parse(fs.readFileSync(0,"utf8")); process.stdout.write(j.field||j.key||"");')"
  if [ -z "$FIELD" ]; then
    echo "Not: field boş. Wizard tamamlanmış olabilir."
    break
  fi

  A="${ANSWERS[$FIELD]:-}"
  [ -n "$A" ] || { echo "HATA: $FIELD için hazır cevap yok"; exit 2; }

  post_wizard_answer "$FIELD" "$A"

  echo "deal.status => $(deal_status)"
  if [ "$(deal_status)" = "READY_FOR_MATCHING" ]; then
    echo "✅ Deal READY_FOR_MATCHING oldu."
    break
  fi
done

STATUS="$(deal_status)"
if [ "$STATUS" != "READY_FOR_MATCHING" ]; then
  echo
  echo "HATA: Deal status READY_FOR_MATCHING olmadı. Şu an: $STATUS"
  echo "Bu durumda wizardNextQuestion / wizardAnswer implementasyonunda status update yok demektir."
  echo "Hızlı kontrol için dosyayı aç:"
  echo "  apps/api/src/leads/leads.service.ts (wizardAnswer içinde deal update var mı?)"
  exit 3
fi

echo
echo "==> Match deal"
curl -sS -i -X POST "$BASE_URL/deals/$DEAL_ID/match" | sed -n '1,140p'
echo
echo "DONE."
