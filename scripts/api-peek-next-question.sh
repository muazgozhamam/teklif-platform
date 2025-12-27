#!/usr/bin/env bash
set -euo pipefail

LEAD_ID="${1:-}"
BASE="${BASE:-http://localhost:3001}"

if [[ -z "$LEAD_ID" ]]; then
  echo "Kullanım: bash scripts/api-peek-next-question.sh <LEAD_ID>"
  exit 1
fi

echo "==> GET $BASE/leads/$LEAD_ID/next"
curl -sS "$BASE/leads/$LEAD_ID/next" | python3 -m json.tool || true
