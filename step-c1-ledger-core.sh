#!/usr/bin/env bash
set -e

API_SRC="apps/api/src"
LEDGER_DIR="$API_SRC/ledger"
BROKER_CTRL="$API_SRC/broker/broker-commissions.controller.ts"

echo "==> Ledger klasoru"
mkdir -p "$LEDGER_DIR"

echo "==> ledger.types.ts"
cat > "$LEDGER_DIR/ledger.types.ts" <<'EOT'
export type LedgerStatus = 'CREATED' | 'PAID' | 'CANCELLED';

export interface LedgerEntry {
  id: string;
  dealId: string;
  amount: number;
  rate: number;
  commission: number;
  net: number;
  status: LedgerStatus;
  createdAt: string;
}
EOT

echo "==> ledger.service.ts"
cat > "$LEDGER_DIR/ledger.service.ts" <<'EOS'
import { Injectable } from '@nestjs/common';
import { LedgerEntry, LedgerStatus } from './ledger.types';

@Injectable()
export class LedgerService {
  private entries: LedgerEntry[] = [];

  create(input: Omit<LedgerEntry, 'id' | 'createdAt' | 'status'>): LedgerEntry {
    const entry: LedgerEntry = {
      id: 'ledg_' + Math.random().toString(36).slice(2, 8),
      status: 'CREATED',
      createdAt: new Date().toISOString(),
      ...input,
    };
    this.entries.push(entry);
    return entry;
  }

  list(): LedgerEntry[] {
    return this.entries;
  }

  updateStatus(id: string, status: LedgerStatus): LedgerEntry {
    const entry = this.entries.find(e => e.id === id);
    if (!entry) throw new Error('Ledger entry not found');
    entry.status = status;
    return entry;
  }
}
EOS

echo "==> ledger.controller.ts"
cat > "$LEDGER_DIR/ledger.controller.ts" <<'EOC'
import { Controller, Get, Patch, Param } from '@nestjs/common';
import { LedgerService } from './ledger.service';

@Controller('ledger/commissions')
export class LedgerController {
  constructor(private readonly ledger: LedgerService) {}

  @Get()
  list() {
    return this.ledger.list();
  }

  @Patch(':id/paid')
  paid(@Param('id') id: string) {
    return this.ledger.updateStatus(id, 'PAID');
  }

  @Patch(':id/cancel')
  cancel(@Param('id') id: string) {
    return this.ledger.updateStatus(id, 'CANCELLED');
  }
}
EOC

echo "==> ledger.module.ts"
cat > "$LEDGER_DIR/ledger.module.ts" <<'EOM'
import { Module } from '@nestjs/common';
import { LedgerService } from './ledger.service';
import { LedgerController } from './ledger.controller';

@Module({
  providers: [LedgerService],
  controllers: [LedgerController],
  exports: [LedgerService],
})
export class LedgerModule {}
EOM

echo "==> AppModule'a LedgerModule ekleniyor"
APP_MODULE="$API_SRC/app.module.ts"
if ! grep -q "LedgerModule" "$APP_MODULE"; then
  sed -i '' '1i\
import { LedgerModule } from "./ledger/ledger.module";\
' "$APP_MODULE"
fi
perl -0777 -i -pe '
s/imports:\s*\[([^\]]*)\]/imports: [\1, LedgerModule]/s
' "$APP_MODULE"

echo "==> Broker controller -> ledger write ekleniyor"
perl -0777 -i -pe '
s/class BrokerCommissionsController \{\n  constructor\(([^\)]*)\)\s*\{/class BrokerCommissionsController {\n  constructor($1, private readonly ledger: any) {/s
' "$BROKER_CTRL"

if ! grep -q "LedgerService" "$BROKER_CTRL"; then
  sed -i '' '1i\
import { LedgerService } from "../ledger/ledger.service";\
' "$BROKER_CTRL"
  perl -0777 -i -pe '
s/private readonly ledger: any/private readonly ledger: LedgerService/s
' "$BROKER_CTRL"
fi

perl -0777 -i -pe '
s/return \{\n\s*dealId,\n\s*\.\.\.result,\n\s*status: .CREATED.,\n\s*\};/const entry = this.ledger.create({ dealId, ...result });\n\n    return entry;/s
' "$BROKER_CTRL"

echo "==> TAMAM (watch mode reload edecek)"
