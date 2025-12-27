#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
DIST_DIR="$API_DIR/dist"
PORT="${PORT:-3001}"

echo "==> 0) Kill anything listening on port $PORT (dev/dist)"
PIDS="$(lsof -nP -t -iTCP:${PORT} -sTCP:LISTEN || true)"
if [[ -n "${PIDS}" ]]; then
  echo "Killing PID(s): ${PIDS}"
  kill -9 ${PIDS} || true
fi

echo
echo "==> 1) Kill any node process running dist/src/main.js (if any)"
# safest: only kill exact dist main.js runners from this repo path
DIST_MAIN="$API_DIR/dist/src/main.js"
RUN_PIDS="$(ps aux | awk -v p="$DIST_MAIN" '$0 ~ p && $0 ~ /node/ {print $2}' || true)"
if [[ -n "${RUN_PIDS}" ]]; then
  echo "Killing dist node PID(s): ${RUN_PIDS}"
  kill -9 ${RUN_PIDS} || true
fi

echo
echo "==> 2) Remove dist folder completely"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo
echo "==> 3) Build API"
cd "$API_DIR"
pnpm -s build

echo
echo "✅ OK: clean dist rebuild finished"
