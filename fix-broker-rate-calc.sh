#!/usr/bin/env bash
set -e

CTRL="apps/api/src/broker/broker-commissions.controller.ts"

echo "==> Broker commission hesaplama zinciri düzeltiliyor"

# Hesaplama zincirini garanti altına al
perl -0777 -i -pe '
s/const rate = body\.rate \?\? await this\.rates\.resolve\([^\)]*\);\s*
\s*const result = this\.commissions\.calculate\([^\)]*\);/const rate = body.rate ?? await this.rates.resolve(body.brokerId);\n    const result = this.commissions.calculate(body.amount, rate);/s
' "$CTRL"

# Ledger write kısmını garanti et
perl -0777 -i -pe '
s/this\.ledger\.create\(\{\s*dealId,\s*\.\.\.result\s*\}\)/this.ledger.create({ dealId, rate, ...result })/s
' "$CTRL"

echo "✅ Broker rate → calculate → ledger zinciri FIXLENDI"
