#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
SRC="$ROOT/apps/api/src/dev/dev-seed.module.ts"
DST="$ROOT/apps/api/src/dev-seed/dev-seed.module.ts"

[ -f "$SRC" ] || { echo "❌ Missing source: $SRC"; exit 1; }
[ -f "$DST" ] || { echo "❌ Missing destination: $DST"; exit 1; }

cp "$DST" "$DST.bak"
cp "$SRC" "$DST"

echo "✅ Replaced dev-seed.module.ts with consultant seeding version"
echo " - Source:", "$SRC"
echo " - Target:", "$DST"
echo " - Backup:", "$DST.bak"

echo
echo "==> API build check"
pnpm -C apps/api -s build
echo "✅ Done."
