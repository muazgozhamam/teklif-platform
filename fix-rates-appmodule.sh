#!/usr/bin/env bash
set -e

APP_MODULE="apps/api/src/app.module.ts"

echo "==> AppModule bulunuyor: $APP_MODULE"

# import ekle
if ! grep -q "RatesModule" "$APP_MODULE"; then
  sed -i '' '1i\
import { RatesModule } from "./rates/rates.module";\
' "$APP_MODULE"
  echo "==> RatesModule import eklendi"
else
  echo "==> RatesModule import zaten var"
fi

# imports array'e ekle
if grep -q "imports:" "$APP_MODULE"; then
  if ! grep -q "RatesModule" "$APP_MODULE"; then
    perl -0777 -i -pe '
      s/imports:\s*\[([^\]]*)\]/imports: [\1, RatesModule]/s
    ' "$APP_MODULE"
  fi
else
  perl -0777 -i -pe '
    s/@Module\s*\(\s*\{/@Module({\n  imports: [RatesModule],/s
  ' "$APP_MODULE"
fi

echo "✅ RatesModule -> AppModule bağlandı"
