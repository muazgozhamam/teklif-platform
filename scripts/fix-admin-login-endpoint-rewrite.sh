#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"

APP_DIR=""
for d in "$ROOT"/apps/*; do
  if [ -f "$d/package.json" ]; then
    if node -e "const j=require('$d/package.json'); process.exit(j.name==='@teklif/admin'?0:1)"; then
      APP_DIR="$d"
      break
    fi
  fi
done
if [ -z "$APP_DIR" ]; then
  echo "HATA: @teklif/admin app bulunamadı."
  exit 1
fi

SRC="$APP_DIR/src"
if [ ! -d "$SRC" ]; then
  echo "HATA: src klasörü yok: $SRC"
  exit 1
fi

echo "==> /auth/login -> /api/auth/login patch (admin app)"

FILES="$(grep -Rsl "/auth/login" "$SRC" 2>/dev/null || true)"
if [ -z "$FILES" ]; then
  echo "UYARI: src içinde /auth/login bulunamadı. Login form başka bir yerde olabilir."
  exit 0
fi

for f in $FILES; do
  perl -0777 -i -pe "s|/auth/login|/api/auth/login|g" "$f"
done

echo "==> OK: patched files:"
echo "$FILES"
