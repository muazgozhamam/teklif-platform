#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE_URL="${BASE_URL:-http://localhost:3001}"

echo "==> ROOT=$ROOT"
echo "==> BASE_URL=$BASE_URL"

echo
echo "==> 1) dist clean + build"
bash "$ROOT/scripts/sprint-next/11-fix-api-dist-enotempty-build.sh"

echo
echo "==> 2) start api dev 3001"
bash "$ROOT/scripts/sprint-next/05-start-api-dev-3001.sh"

echo
echo "==> 3) smoke pagination"
bash "$ROOT/scripts/sprint-next/36-smoke-listings-pagination.sh" | tee "$ROOT/.tmp/99.golden.pagination.log"

echo
echo "✅ GOLDEN OK. Log: $ROOT/.tmp/99.golden.pagination.log"
