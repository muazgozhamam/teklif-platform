#!/usr/bin/env bash
set -e

API_DIR="apps/api"
PRISMA_SCHEMA="$API_DIR/prisma/schema.prisma"
LEDGER_SERVICE="$API_DIR/src/ledger/ledger.service.ts"

echo "==> Prisma model ekleniyor (LedgerEntry)"

# LedgerEntry modelini ekle
if ! grep -q "model LedgerEntry" "$PRISMA_SCHEMA"; then
  cat >> "$PRISMA_SCHEMA" <<'EOM'

model LedgerEntry {
  id         String   @id @default(cuid())
  dealId     String
  amount     Int
  rate       Int
  commission Int
  net        Int
  status     String
  createdAt  DateTime @default(now())
}
EOM
fi

echo "==> Prisma migrate"
cd "$API_DIR"
pnpm prisma migrate dev --name add_ledger_entry

echo "==> LedgerService DB-backed yapiliyor"

cat > "$LEDGER_SERVICE" <<'EOS'
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LedgerEntry } from '@prisma/client';

@Injectable()
export class LedgerService {
  constructor(private readonly prisma: PrismaService) {}

  create(input: Omit<LedgerEntry, 'id' | 'createdAt'>): Promise<LedgerEntry> {
    return this.prisma.ledgerEntry.create({
      data: input,
    });
  }

  list(): Promise<LedgerEntry[]> {
    return this.prisma.ledgerEntry.findMany({
      orderBy: { createdAt: 'desc' },
    });
  }

  updateStatus(id: string, status: string): Promise<LedgerEntry> {
    return this.prisma.ledgerEntry.update({
      where: { id },
      data: { status },
    });
  }
}
EOS

echo "==> TAMAM (watch mode reload edecek)"
