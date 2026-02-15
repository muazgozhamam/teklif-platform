#!/usr/bin/env bash
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR/.." && pwd)"

if [ ! -f "$ROOT/pnpm-workspace.yaml" ]; then
  echo "❌ Repo root bulunamadı (pnpm-workspace.yaml yok). ROOT=$ROOT"
  exit 1
fi

MAIN="$ROOT/apps/api/src/main.ts"
if [ ! -f "$MAIN" ]; then
  echo "❌ Missing: $MAIN"
  exit 1
fi

echo "==> MAIN=$MAIN"
echo
echo "==> Hits (rg):"
rg -n "useGlobalPipes|ValidationPipe|pipe\(|pipes|class-validator|class-transformer" "$MAIN" || true

echo
echo "==> main.ts snippet (top 220 lines):"
nl -ba "$MAIN" | sed -n '1,220p'
