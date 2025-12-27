#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
DASH="$ROOT/apps/dashboard"

APP_DIR="$DASH/src/app"
if [ ! -d "$APP_DIR" ]; then APP_DIR="$DASH/app"; fi
if [ ! -d "$APP_DIR" ]; then
  echo "HATA: Next App Router klasörü yok (src/app veya app)."
  exit 1
fi

PAGE="$APP_DIR/admin/users/page.tsx"
if [ ! -f "$PAGE" ]; then
  echo "Admin users page standart yerde yok, arıyorum..."
  PAGE="$(find "$APP_DIR" -name "page.tsx" | grep -E "/admin/.*/users/" | head -n 1 || true)"
fi

if [ -z "${PAGE:-}" ] || [ ! -f "$PAGE" ]; then
  echo "HATA: admin/users page bulunamadı."
  exit 1
fi

echo "OK: Page -> $PAGE"

# Page içinden import edilen dosyayı bul (ilk from '...')
IMPORTS="$(grep -nE "from ['\"][^'\"]+['\"]" "$PAGE" || true)"

# Öncelik: features/admin veya admin-users benzeri
CAND="$(echo "$IMPORTS" | grep -E "admin|users|features" | head -n 1 | sed -E "s/^.*from ['\"]([^'\"]+)['\"].*$/\1/")"

# Eğer bulamazsa, tüm dashboard/src içinde /admin/users stringini arayacağız
TARGET=""

resolve_alias () {
  local p="$1"
  p="${p#@/}"
  if [ -f "$DASH/src/$p.tsx" ]; then echo "$DASH/src/$p.tsx"; return; fi
  if [ -f "$DASH/src/$p.ts" ]; then echo "$DASH/src/$p.ts"; return; fi
  if [ -f "$DASH/$p.tsx" ]; then echo "$DASH/$p.tsx"; return; fi
  if [ -f "$DASH/$p.ts" ]; then echo "$DASH/$p.ts"; return; fi
  echo ""
}

if [ -n "$CAND" ]; then
  TARGET="$(resolve_alias "$CAND")"
fi

if [ -z "$TARGET" ]; then
  echo "Import'tan component çözümlenemedi, içerik araması: /admin/users"
  TARGET="$(grep -Rsl "/admin/users" "$DASH/src" 2>/dev/null | head -n 1 || true)"
fi

if [ -z "$TARGET" ] || [ ! -f "$TARGET" ]; then
  echo "HATA: Patch edilecek component bulunamadı."
  echo "Manual kontrol:"
  echo "  grep -R \"/admin/users\" apps/dashboard/src"
  exit 1
fi

echo "==> Patch edilecek dosya:"
echo "  $TARGET"

# Proxy endpointlere yönlendir
perl -0777 -i -pe "s|/admin/users\\b|/api/admin/users|g" "$TARGET"
perl -0777 -i -pe "s|/api/admin/users/\\$\\{userId\\}/role|/api/admin/users/${userId}/role|g" "$TARGET"

echo "==> OK: UI artık Next proxy endpointlerine gidiyor."
