#!/usr/bin/env bash
set -e

APP_MODULE="apps/api/src/app.module.ts"
SERVICE_IMPORT='import { CommissionsService } from "./commissions/commissions.service";'

echo "==> CommissionsService AppModule'a ekleniyor"

# import ekle
if ! grep -q "CommissionsService" "$APP_MODULE"; then
  sed -i '' "1i\\
$SERVICE_IMPORT
" "$APP_MODULE"
fi

# providers array varsa ekle, yoksa oluştur
if grep -q "providers:" "$APP_MODULE"; then
  perl -0777 -i -pe '
    s/providers:\s*\[([^\]]*)\]/providers: [\1, CommissionsService]/s
  ' "$APP_MODULE"
else
  perl -0777 -i -pe '
    s/@Module\s*\(\s*\{/@Module({\n  providers: [CommissionsService],/s
  ' "$APP_MODULE"
fi

echo "==> TAMAM (watch mode reload edecek)"
