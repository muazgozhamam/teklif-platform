#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API="$ROOT/apps/api"

echo "==> ROOT=$ROOT"
echo "==> API =$API"
echo

if ! command -v rg >/dev/null 2>&1; then
  echo "HATA: rg (ripgrep) yok. Kur:"
  echo "  brew install ripgrep"
  exit 1
fi

echo "==> 1) Deal status enum / match guard mesajı"
rg -n --hidden --no-ignore -S "Deal not ready for match|not ready for match|status=OPEN|READY_FOR_MATCH|match \\(" "$API/src" || true
echo

echo "==> 2) match endpoint nerede?"
rg -n --hidden --no-ignore -S "@Post\\(.*match|/match\\)|match\\(" "$API/src" || true
echo

echo "==> 3) Deal status update endpointleri (PATCH/PUT) arama"
rg -n --hidden --no-ignore -S "@Patch\\(|@Put\\(|updateStatus|setStatus|status:" "$API/src/deals" "$API/src" || true
echo

echo "==> 4) Ledger endpoint nerede?"
rg -n --hidden --no-ignore -S "ledger|Ledger" "$API/src" || true
echo

echo "==> 5) Broker deals ledger route olası controller"
rg -n --hidden --no-ignore -S "broker.*deals|/broker/deals|Broker.*Deal" "$API/src" || true
echo

echo "DONE."
