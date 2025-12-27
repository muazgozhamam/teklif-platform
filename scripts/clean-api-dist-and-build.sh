#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_DIR="$ROOT/apps/api"
DIST="$API_DIR/dist"

echo "==> ROOT=$ROOT"
echo "==> API_DIR=$API_DIR"
echo "==> Cleaning dist: $DIST"

if [ -d "$DIST" ]; then
  echo "Found dist. Trying chmod + delete..."
  chmod -R u+rwX "$DIST" || true
  rm -rf "$DIST"
fi

echo "OK: dist removed"

echo "==> Build only API to verify"
cd "$API_DIR"
pnpm -s build

echo
echo "DONE."
