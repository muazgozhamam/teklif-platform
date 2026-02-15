#!/usr/bin/env bash
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR/.." && pwd)"

if [ ! -f "$ROOT/pnpm-workspace.yaml" ]; then
  echo "❌ Repo root bulunamadı (pnpm-workspace.yaml yok). ROOT=$ROOT"
  exit 1
fi

FILE="$ROOT/scripts/smoke-wizard-to-match-mac.sh"
if [ ! -f "$FILE" ]; then
  echo "❌ Missing: $FILE"
  exit 1
fi

echo "==> FILE=$FILE"
echo
echo "==> Key/field extraction related hits:"
rg -n --no-heading "(\.key|\"key\"|key=|key\s*=|field|\"field\"|question|Wizard|answering|jq|node\s+-p|node\s+-e|python|sed|awk)" "$FILE" || true

echo
echo "==> Head (first 260 lines):"
nl -ba "$FILE" | sed -n '1,260p'
