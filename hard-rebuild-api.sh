#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API="$ROOT/apps/api"
SRC="$API/src"

echo "==> 0) Show any remaining CONSULTANT role usage in src (should be none; .bak can be ignored)"
grep -R --line-number 'role: "CONSULTANT"' "$SRC" || true
grep -R --line-number "role: 'CONSULTANT'" "$SRC" || true
echo

echo "==> 1) Kill anything listening on :3001 (if any)"
PIDS="$(lsof -nP -iTCP:3001 -sTCP:LISTEN -t || true)"
if [[ -n "${PIDS}" ]]; then
  echo "Killing PIDs: ${PIDS}"
  kill -9 ${PIDS} || true
else
  echo "No listener on :3001"
fi
echo

echo "==> 2) Remove dist to avoid stale runtime"
rm -rf "$API/dist"
echo "Removed: $API/dist"
echo

echo "==> 3) Prisma generate + build"
cd "$API"
pnpm -s prisma generate --schema prisma/schema.prisma
pnpm -s build
echo

echo "✅ Hard rebuild done."
echo "Now start API in this terminal:"
echo "  cd apps/api && pnpm start:dev"
echo "Then retry:"
echo "  curl -i -X POST \"http://localhost:3001/deals/cmjmdz7rj0001grmfeyx69qie/match\""
