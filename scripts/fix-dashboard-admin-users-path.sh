#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
DASH="$ROOT/apps/dashboard"

if [ ! -d "$DASH" ]; then
  echo "HATA: apps/dashboard yok"
  exit 1
fi

echo "==> Admin Users component aranıyor..."

# 1) /admin/users route page'i bul
APP_DIR="$DASH/src/app"
if [ ! -d "$APP_DIR" ]; then APP_DIR="$DASH/app"; fi

PAGE="$APP_DIR/admin/users/page.tsx"
if [ ! -f "$PAGE" ]; then
  echo "UYARI: /admin/users page bulunamadı: $PAGE"
  echo "Mevcut admin/users page arıyorum..."
  PAGE="$(find "$APP_DIR" -path "*admin*users*page.tsx" | head -n 1 || true)"
fi

if [ -z "${PAGE:-}" ] || [ ! -f "$PAGE" ]; then
  echo "HATA: admin users page bulunamadı. $APP_DIR altında admin/users/page.tsx olmalı."
  exit 1
fi

echo "OK: Page -> $PAGE"

# 2) Page'in import ettiği component'i yakala (AdminUsersPage import satırı)
IMPORT_PATH="$(grep -E "from ['\"].*admin-users.*['\"]" "$PAGE" | sed -E "s/^.*from ['\"]([^'\"]+)['\"].*$/\1/" | head -n 1 || true)"

TARGET=""
if [ -n "$IMPORT_PATH" ]; then
  # relative/alias olabilir; birkaç olasılık dene
  C1="$DASH/src/${IMPORT_PATH#@/}.tsx"
  C2="$DASH/${IMPORT_PATH#@/}.tsx"
  C3="$DASH/src/${IMPORT_PATH#@/}.ts"
  C4="$DASH/${IMPORT_PATH#@/}.ts"
  for c in "$C1" "$C2" "$C3" "$C4"; do
    if [ -f "$c" ]; then TARGET="$c"; break; fi
  done
fi

# 3) Bulamazsak repo içinde API path'i kullanan dosyayı ara
if [ -z "$TARGET" ]; then
  echo "Import'tan bulunamadı, içerik araması yapıyorum..."
  TARGET="$(grep -Rsl "/admin/users" "$DASH/src" 2>/dev/null | head -n 1 || true)"
fi

if [ -z "$TARGET" ] || [ ! -f "$TARGET" ]; then
  echo "HATA: Admin Users component bulunamadı."
  echo "Manual: grep -R \"/admin/users\" apps/dashboard/src"
  exit 1
fi

echo "==> Patch edilecek component:"
echo "  $TARGET"

# 4) /admin/users -> /api/admin/users, /admin/users/:id/role -> /api/admin/users/:id/role
perl -0777 -i -pe "s|/admin/users\\b|/api/admin/users|g" "$TARGET"

echo "==> OK: component proxy endpoint'e yönlendirildi."
