#!/usr/bin/env bash
set -e

BROKER_MODULE="apps/api/src/broker/broker.module.ts"

echo "==> BrokerModule -> CommissionsModule baglaniyor"

# import ekle
if ! grep -q "CommissionsModule" "$BROKER_MODULE"; then
  sed -i '' '1i\
import { CommissionsModule } from "../commissions/commissions.module";\
' "$BROKER_MODULE"
fi

# imports array varsa ekle, yoksa oluştur
if grep -q "imports:" "$BROKER_MODULE"; then
  perl -0777 -i -pe '
    s/imports:\s*\[([^\]]*)\]/imports: [\1, CommissionsModule]/s
  ' "$BROKER_MODULE"
else
  perl -0777 -i -pe '
    s/@Module\s*\(\s*\{/@Module({\n  imports: [CommissionsModule],/s
  ' "$BROKER_MODULE"
fi

echo "==> TAMAM (watch mode reload edecek)"
