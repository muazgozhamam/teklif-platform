#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE_URL:-http://localhost:3001}"
N="${N:-10}"

echo "==> BASE=$BASE"
echo "==> N=$N"

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
  LEAD="$(curl -sS -X POST "$BASE/leads" -H "Content-Type: application/json" -d "{\"initialText\":\"smoke v2 $i\"}")"
  LEAD_ID="$(echo "$LEAD" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")"

  # wizard
  Q="$(curl -sS "$BASE/leads/$LEAD_ID/next")"
  KEY="$(echo "$Q" | python3 -c "import sys,json; j=json.load(sys.stdin); print(j.get('key') or j.get('field') or '')")"
  while [[ "$KEY" != "" ]]; do
    case "$KEY" in
      city) ans="Konya" ;;
      district) ans="Meram" ;;
      type) ans="SATILIK" ;;
      rooms) ans="2+1" ;;
      *) ans="x" ;;
    esac
    curl -sS -X POST "$BASE/leads/$LEAD_ID/wizard/answer" -H "Content-Type: application/json" -d "{\"key\":\"$KEY\",\"answer\":\"$ans\"}" >/dev/null
    Q="$(curl -sS "$BASE/leads/$LEAD_ID/next")"
    KEY="$(echo "$Q" | python3 -c "import sys,json; j=json.load(sys.stdin); print(j.get('key') or j.get('field') or '')")"
    DONE="$(echo "$Q" | python3 -c "import sys,json; j=json.load(sys.stdin); print('1' if j.get('done') else '0')")"
    if [[ "$DONE" == "1" ]]; then
      break
    fi
  done

  DEAL="$(curl -sS "$BASE/deals/by-lead/$LEAD_ID")"
  DEAL_ID="$(echo "$DEAL" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")"

  MATCH="$(curl -sS -X POST "$BASE/deals/$DEAL_ID/match")"
  CID="$(echo "$MATCH" | python3 -c "import sys,json; print(json.load(sys.stdin).get('consultantId','(null)'))")"
  inc "$CID"

  echo "[$i/$N] deal=$DEAL_ID consultant=$CID"
done

echo
echo "==> DISTRIBUTION"
cat "$counts_file"
