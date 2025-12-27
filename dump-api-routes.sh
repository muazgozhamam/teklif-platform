#!/usr/bin/env bash
set -euo pipefail

API_DIR="$(pwd)/apps/api"

echo "==> 1) Build (route dump için dist lazım olabilir)"
cd "$API_DIR"
pnpm -s build

echo
echo "==> 2) Route keywords scan (src)"
cd "$(pwd)/../.."

echo
echo "--- Possible deals routes in src ---"
grep -R --line-number -E 'Controller\(|@Controller|/deals|deals' apps/api/src/deals apps/api/src 2>/dev/null \
  | head -n 200 || true

echo
echo "--- Swagger path hints (src) ---"
grep -R --line-number -E '@ApiTags\(|@Get\(|@Post\(|@Patch\(|@Delete\(' apps/api/src/deals apps/api/src 2>/dev/null \
  | grep -i deals \
  | head -n 200 || true

echo
echo "✅ DONE. If you see a GET path above, use that in curl."
