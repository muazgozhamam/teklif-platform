#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"

if [ ! -d "$API_DIR/src" ]; then
  echo "apps/api/src bulunamadı. Şu an: $ROOT"
  exit 1
fi

echo "==> Fix: jwt-auth.guard + @Roles('ADMIN') type uyumsuzluğu"

mkdir -p "$API_DIR/src/auth"

# 1) jwt-auth.guard.ts garanti
cat > "$API_DIR/src/auth/jwt-auth.guard.ts" <<'TS'
import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}
TS

# 2) role.enum.ts garanti
cat > "$API_DIR/src/auth/role.enum.ts" <<'TS'
export enum Role {
  USER = 'USER',
  BROKER = 'BROKER',
  ADMIN = 'ADMIN',
}
TS

# 3) roles.decorator.ts garanti (Role enum ile)
cat > "$API_DIR/src/auth/roles.decorator.ts" <<'TS'
import { SetMetadata } from '@nestjs/common';
import { Role } from './role.enum';

export const ROLES_KEY = 'roles';
export const Roles = (...roles: Role[]) => SetMetadata(ROLES_KEY, roles);
TS

# 4) admin.controller.ts patch
ADMIN_CTRL="$API_DIR/src/admin/admin.controller.ts"
if [ ! -f "$ADMIN_CTRL" ]; then
  echo "HATA: $ADMIN_CTRL bulunamadı."
  exit 1
fi

# JwtAuthGuard import path'i normalize et (dosya artık kesin var)
perl -0777 -i -pe "s|from\\s+['\\\"]\\.{2}/auth/jwt-auth\\.guard['\\\"]|from '../auth/jwt-auth.guard'|g" "$ADMIN_CTRL"

# @Roles('ADMIN') -> @Roles(Role.ADMIN)
perl -0777 -i -pe "s/\\@Roles\\(\\s*['\\\"]ADMIN['\\\"]\\s*\\)/\\@Roles(Role.ADMIN)/g" "$ADMIN_CTRL"

# Role importunu ekle (yoksa)
if ! grep -q "from '../auth/role.enum'" "$ADMIN_CTRL"; then
  # Dosyanın en üstüne ekle (en garanti yöntem)
  perl -0777 -i -pe "s|^|import { Role } from '../auth/role.enum';\\n|s" "$ADMIN_CTRL"
fi

echo "==> OK: Fix uygulandı."
echo "Kontrol:"
echo " - $API_DIR/src/auth/jwt-auth.guard.ts"
echo " - $API_DIR/src/auth/role.enum.ts"
echo " - $API_DIR/src/admin/admin.controller.ts (Roles(Role.ADMIN))"
