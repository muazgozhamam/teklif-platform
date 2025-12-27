#!/usr/bin/env bash
# ÇALIŞILACAK KÖK: ~/Desktop/teklif-platform
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

DEAL_ID="${1:-${DEAL_ID:-}}"
if [[ -z "$DEAL_ID" ]]; then
  echo "KULLANIM:"
  echo "  DEAL_ID=<dealId> bash scripts/create-listing-and-link-deal.sh"
  echo "veya"
  echo "  bash scripts/create-listing-and-link-deal.sh <dealId>"
  exit 1
fi

# Dev seed ile oluşturduğumuz consultant
ACTOR_ID="${ACTOR_ID:-consultant_seed_1}"

API_BASE="${API_BASE:-http://localhost:3001}"

echo "ROOT=$ROOT"
echo "API_BASE=$API_BASE"
echo "DEAL_ID=$DEAL_ID"
echo "ACTOR_ID=$ACTOR_ID"
echo

echo "==> 1) Listing create"
CREATE_RESP="$(curl -sS -X POST "$API_BASE/listings" \
  -H "Content-Type: application/json" \
  -H "x-user-id: $ACTOR_ID" \
  -d '{"title":"Test Listing","city":"Konya","district":"Selçuklu","type":"SATILIK","rooms":"2+1"}'
)"

echo "CREATE_RESP=$CREATE_RESP"
echo

LISTING_ID="$(node -e 'const s=process.argv[1]; try{const j=JSON.parse(s); process.stdout.write(j.id||"");}catch(e){process.stdout.write("");}' "$CREATE_RESP")"

if [[ -z "$LISTING_ID" ]]; then
  echo "HATA: Listing ID parse edilemedi. Response yukarıda."
  exit 1
fi

echo "✅ LISTING_ID=$LISTING_ID"
echo

echo "==> 2) Link listing to deal"
LINK_RESP="$(curl -sS -X POST "$API_BASE/deals/$DEAL_ID/link-listing/$LISTING_ID" \
  -H "Content-Type: application/json" \
  -H "x-user-id: $ACTOR_ID"
)"
echo "LINK_RESP=$LINK_RESP"
echo

echo "==> 3) Verify deal now has listingId"
curl -sS "$API_BASE/deals/$DEAL_ID" | sed 's/^/DEAL: /'
echo
echo "✅ DONE"
