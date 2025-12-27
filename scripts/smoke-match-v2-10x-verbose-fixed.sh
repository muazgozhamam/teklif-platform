#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE_URL:-http://localhost:3001}"
N="${N:-10}"
CURL="curl -sS --connect-timeout 2 --max-time 8"

echo "==> BASE=$BASE"
echo "==> N=$N"
echo

counts_file="$(mktemp)"
echo "{}" > "$counts_file"

inc() {
  local k="$1"
  python3 - <<PY "$counts_file" "$k"
import json, sys
p=sys.argv[1]; k=sys.argv[2]
d=json.load(open(p))
d[k]=d.get(k,0)+1
json.dump(d, open(p,"w"), indent=2)
PY
}

for i in $(seq 1 "$N"); do
  echo "==> [$i/$N] create lead"
  LEAD="$($CURL -X POST "$BASE/leads" -H "Content-Type: application/json" -d "{\"initialText\":\"smoke v2 fixed $i\"}")"
  LEAD_ID="$(echo "$LEAD" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")"
  echo "    leadId=$LEAD_ID"

  echo "    wizard: answering via /leads/:id/answer"
  for step in $(seq 1 10); do
    Q="$($CURL "$BASE/leads/$LEAD_ID/next")"
    DONE="$(echo "$Q" | python3 -c "import sys,json; j=json.load(sys.stdin); print('1' if j.get('done') else '0')")"
    KEY="$(echo "$Q"  | python3 -c "import sys,json; j=json.load(sys.stdin); print(j.get('key') or j.get('field') or '')")"

    if [[ "$DONE" == "1" || -z "$KEY" ]]; then
      echo "    wizard done"
      break
    fi

    case "$KEY" in
      city) ans="Konya" ;;
      district) ans="Meram" ;;
      type) ans="SATILIK" ;;
      rooms) ans="2+1" ;;
      *) ans="x" ;;
    esac

    echo "      step $step: field=$KEY value=$ans"
    OUT="$($CURL -X POST "$BASE/leads/$LEAD_ID/answer" \
      -H "Content-Type: application/json" \
      -d "{\"field\":\"$KEY\",\"value\":\"$ans\"}")" || true
  done

  echo "    get deal"
  DEAL="$($CURL "$BASE/deals/by-lead/$LEAD_ID")"
  DEAL_ID="$(echo "$DEAL" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")"
  STATUS="$(echo "$DEAL" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','?'))")"
  echo "    dealId=$DEAL_ID status=$STATUS"

  echo "    match"
  MATCH="$($CURL -X POST "$BASE/deals/$DEAL_ID/match")"
  echo "    matchResp: $(echo "$MATCH" | python3 -c "import sys,json; j=json.load(sys.stdin); print('status='+str(j.get('status'))+' consultantId='+str(j.get('consultantId')))")"
  CID="$(echo "$MATCH" | python3 -c "import sys,json; print(json.load(sys.stdin).get('consultantId','(null)'))")"
  inc "$CID"
  echo
done

echo "==> DISTRIBUTION"
cat "$counts_file"
