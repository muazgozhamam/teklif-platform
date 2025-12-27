#!/usr/bin/env bash
set -euo pipefail
PIDS="$(lsof -nP -t -iTCP:3001 -sTCP:LISTEN || true)"
if [ -z "${PIDS}" ]; then
  echo "✅ 3001 already free"
  exit 0
fi
echo "🔪 Killing PID(s): ${PIDS}"
kill -9 ${PIDS} || true
echo "✅ 3001 freed"
