#!/usr/bin/env bash
set -euo pipefail

API_DIR="$(pwd)/apps/api"
DEC="$API_DIR/src/common/roles.decorator.ts"
GUARD="$API_DIR/src/common/roles.guard.ts"

if [ ! -f "$DEC" ]; then
  echo "HATA: roles.decorator bulunamadı: $DEC"
  exit 1
fi

echo "==> Fix: common/roles.decorator.ts string tabanlı yapılıyor"

cat > "$DEC" <<'TS'
import { SetMetadata } from '@nestjs/common';

export const ROLES_KEY = 'roles';

/**
 * String tabanlı Roles decorator:
 * - Role type/enum çakışmalarında TS hatası üretmez
 * - Guard tarafında string kıyas ile çalışır
 */
export const Roles = (...roles: readonly string[]) => SetMetadata(ROLES_KEY, roles);
TS

if [ -f "$GUARD" ]; then
  echo "==> Fix: common/roles.guard.ts normalize ediliyor (string roles)"
  # Role importunu kaldırmaya çalış (varsa)
  perl -0777 -i -pe "s/import\\s+\\{\\s*Role\\s*\\}\\s+from\\s+['\\\"][^'\\\"]+['\\\"];\\s*\\n//g" "$GUARD" || true
  # Role[] -> string[] (varsa)
  perl -0777 -i -pe "s/Role\\[\\]/string\\[\\]/g" "$GUARD" || true
fi

echo "==> OK: Patch tamam"
echo " - $DEC"
[ -f "$GUARD" ] && echo " - $GUARD"
