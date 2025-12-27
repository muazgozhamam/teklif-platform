#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOG="$ROOT/.tmp/64.pagination-smoke.log"

echo "==> ROOT=$ROOT"
echo

echo "==> 1) Show last smoke log (64) tail"
if [ -f "$LOG" ]; then
  tail -n 120 "$LOG"
else
  echo "⚠️ Missing log: $LOG"
fi
echo

echo "==> 2) git status"
cd "$ROOT"
git status --porcelain || true
echo

echo "==> 3) git diff (summary)"
git diff --stat || true
echo

echo "==> 4) API dev PID on 3001 (if any)"
lsof -nP -t -iTCP:3001 -sTCP:LISTEN || echo "(none)"
echo

echo "✅ Snapshot done."
