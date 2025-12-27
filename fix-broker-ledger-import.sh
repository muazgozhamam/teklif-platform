#!/usr/bin/env bash
set -e

BROKER_MODULE="apps/api/src/broker/broker.module.ts"

echo "==> BrokerModule -> LedgerModule baglaniyor"

# import ekle
if ! grep -q "LedgerModule" "$BROKER_MODULE"; then
  sed -i '' '1i\
import { LedgerModule } from "../ledger/ledger.module";\
' "$BROKER_MODULE"
fi

# imports array varsa ekle, yoksa oluştur
if grep -q "imports:" "$BROKER_MODULE"; then
  perl -0777 -i -pe '
    s/imports:\s*\[([^\]]*)\]/imports: [\1, LedgerModule]/s
  ' "$BROKER_MODULE"
else
  perl -0777 -i -pe '
    s/@Module\s*\(\s*\{/@Module({\n  imports: [LedgerModule],/s
  ' "$BROKER_MODULE"
fi

echo "==> TAMAM (watch mode reload edecek)"
