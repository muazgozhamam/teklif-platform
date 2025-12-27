#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
CTRL="$API_DIR/src/admin/admin.controller.ts"

if [ ! -f "$CTRL" ]; then
  echo "HATA: admin.controller.ts bulunamadı: $CTRL"
  exit 1
fi

echo "==> Admin controller içindeki Roles import'u tespit ediliyor..."

# import satırını bul (Roles içeren import)
IMPORT_LINE="$(grep -nE "import\s+\{[^}]*\bRoles\b[^}]*\}\s+from\s+['\"][^'\"]+['\"]" "$CTRL" | head -n 1 || true)"
if [ -z "$IMPORT_LINE" ]; then
  echo "HATA: $CTRL içinde Roles import satırı bulunamadı."
  echo "Kontrol için:"
  echo "  grep -n \"Roles\" $CTRL"
  exit 1
fi

LINE_NO="$(echo "$IMPORT_LINE" | cut -d: -f1)"
PATH_PART="$(echo "$IMPORT_LINE" | sed -E "s/^.*from\s+['\"]([^'\"]+)['\"].*$/\1/")"

echo "Bulunan import (satır $LINE_NO): $PATH_PART"

# target dosyayı resolve et
SRC_DIR="$API_DIR/src"
ADMIN_DIR="$SRC_DIR/admin"
TARGET=""

if [[ "$PATH_PART" == .* ]]; then
  # relative path
  # admin.controller.ts dosyasının klasörü src/admin olduğundan buradan resolve ediyoruz
  RESOLVED="$ADMIN_DIR/$PATH_PART"
  # normalize ../ ve ./ (python kullanmadan basitçe realpath dene)
  if command -v realpath >/dev/null 2>&1; then
    RESOLVED="$(realpath "$RESOLVED" 2>/dev/null || echo "$RESOLVED")"
  fi

  # .ts ekle (eğer klasör ise index.ts varsayımı yapma; önce .ts dene)
  if [ -f "${RESOLVED}.ts" ]; then
    TARGET="${RESOLVED}.ts"
  elif [ -f "$RESOLVED" ]; then
    TARGET="$RESOLVED"
  else
    # bazen path "auth/roles.decorator" gibi src köküne göre import edilir (alias yoksa)
    if [ -f "$SRC_DIR/$PATH_PART.ts" ]; then
      TARGET="$SRC_DIR/$PATH_PART.ts"
    elif [ -f "$SRC_DIR/$PATH_PART" ]; then
      TARGET="$SRC_DIR/$PATH_PART"
    fi
  fi
else
  # non-relative import: muhtemelen path alias. Bu durumda repo içinde arayacağız.
  echo "Non-relative import görüldü (alias olabilir). Repo içinde Roles decorator aranıyor..."
  if command -v rg >/dev/null 2>&1; then
    CAND="$(rg -n --hidden --no-ignore -S "export const Roles\s*=" "$SRC_DIR" | head -n 1 | cut -d: -f1 || true)"
  else
    CAND="$(grep -Rsn "export const Roles" "$SRC_DIR" | head -n 1 | cut -d: -f1 || true)"
  fi
  TARGET="$CAND"
fi

if [ -z "$TARGET" ] || [ ! -f "$TARGET" ]; then
  echo "HATA: Roles import edilen dosya çözümlenemedi."
  echo "Admin controller import line:"
  echo "$IMPORT_LINE"
  echo
  echo "Alternatif arama (manual):"
  echo "  rg -n \"export const Roles\" apps/api/src"
  exit 1
fi

echo "==> Patch edilecek Roles decorator dosyası:"
echo "  $TARGET"

# Dosyayı string tabanlı decorator ile overwrite et
cat > "$TARGET" <<'TS'
import { SetMetadata } from '@nestjs/common';

export const ROLES_KEY = 'roles';

/**
 * String tabanlı Roles decorator:
 * - Projede Role type/enum çakışmalarında TS hatası üretmez
 * - Guard tarafında string kıyas ile çalışır
 */
export const Roles = (...roles: readonly string[]) => SetMetadata(ROLES_KEY, roles);
TS

echo "==> OK: Roles decorator patchlendi."

# Bonus: guard içinde Role[] yazıyorsa string[]'e çevir (varsa)
GUARD1="$API_DIR/src/auth/roles.guard.ts"
if [ -f "$GUARD1" ]; then
  perl -0777 -i -pe "s/Role\\[\\]/string\\[\\]/g" "$GUARD1" || true
  perl -0777 -i -pe "s/import \\{ Role \\} from '\\.\\/role\\.enum';\\s*\\n//g" "$GUARD1" || true
  echo "==> Not: roles.guard.ts normalize edildi (varsa)."
fi

echo "==> Bitti. Şimdi build al."
