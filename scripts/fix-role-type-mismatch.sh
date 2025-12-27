#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"

DEC="$API_DIR/src/auth/roles.decorator.ts"
CTRL="$API_DIR/src/admin/admin.controller.ts"
GUARD="$API_DIR/src/auth/roles.guard.ts"

if [ ! -f "$DEC" ]; then
  echo "HATA: roles.decorator.ts yok: $DEC"
  exit 1
fi
if [ ! -f "$CTRL" ]; then
  echo "HATA: admin.controller.ts yok: $CTRL"
  exit 1
fi

echo "==> Fix2: Role type mismatch (Roles decorator'ü string tabanlı yapıyoruz)"

# 1) roles.decorator.ts'yi string roles olacak şekilde overwrite et (en hızlı stabil çözüm)
cat > "$DEC" <<'TS'
import { SetMetadata } from '@nestjs/common';

export const ROLES_KEY = 'roles';

/**
 * Hızlı/uyumlu çözüm:
 * Projede birden fazla Role type/enum çakışması olduğunda TS hatası üretmemek için
 * decorator string role değerleri ile çalışır. Guard tarafında da string kıyas yapılır.
 */
export const Roles = (...roles: readonly string[]) => SetMetadata(ROLES_KEY, roles);
TS

# 2) roles.guard.ts: requiredRoles tipini string[] olarak normalize et (varsa)
if [ -f "$GUARD" ]; then
  perl -0777 -i -pe "s/Role\\[\\]/string\\[\\]/g" "$GUARD" || true
  perl -0777 -i -pe "s/import \\{ Role \\} from '\\.\\/role\\.enum';\\s*\\n//g" "$GUARD" || true
fi

# 3) admin.controller.ts: @Roles(Role.ADMIN) -> @Roles('ADMIN')
perl -0777 -i -pe "s/\\@Roles\\(\\s*Role\\.ADMIN\\s*\\)/\\@Roles('ADMIN')/g" "$CTRL"

# Role importunu kaldır (kullanmıyoruz artık)
perl -0777 -i -pe "s/^import \\{ Role \\} from '\\.\\.\\/auth\\/role\\.enum';\\s*\\n//m" "$CTRL"

echo "==> OK: Roles decorator string tabanlı, controller patchlendi."
