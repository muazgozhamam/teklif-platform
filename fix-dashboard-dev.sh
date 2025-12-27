#!/usr/bin/env bash
set -euo pipefail

DASH="$HOME/Desktop/teklif-platform/apps/dashboard"

echo "==> Killing any running Next.js dev servers (best effort)..."
pkill -f "next dev" || true
pkill -f "node.*next" || true

echo "==> Freeing ports 3000 and 3002 (best effort)..."
for p in 3000 3002; do
  PIDS="$(lsof -ti tcp:$p -sTCP:LISTEN 2>/dev/null || true)"
  if [ -n "${PIDS}" ]; then
    echo " - Killing PIDs on port $p: $PIDS"
    kill -9 $PIDS || true
  fi
done

if [ ! -d "$DASH" ]; then
  echo "ERROR: Dashboard folder not found at: $DASH"
  exit 1
fi

echo "==> Cleaning dashboard .next (lock files)..."
rm -rf "$DASH/.next"

if [ -f "$DASH/pnpm-lock.yaml" ]; then
  echo "==> Removing nested lockfile (apps/dashboard/pnpm-lock.yaml)..."
  rm -f "$DASH/pnpm-lock.yaml"
fi

echo "==> Starting dashboard on port 3000..."
cd "$DASH"

# Ensure deps are consistent with workspace
pnpm install

# Start on 3000
exec pnpm dev --port 3000
