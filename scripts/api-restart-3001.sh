#!/usr/bin/env bash
set -euo pipefail

API_DIR="apps/api"

echo "==> 1) 3001 dinleyen process var mı?"
PID="$(lsof -nP -iTCP:3001 -sTCP:LISTEN -t 2>/dev/null || true)"
if [[ -n "${PID:-}" ]]; then
  echo " - 3001 PID=$PID -> kill -9"
  kill -9 "$PID" || true
else
  echo " - 3001 boş"
fi

echo
echo "==> 2) API başlat"
cd "$API_DIR"
pnpm start:dev
