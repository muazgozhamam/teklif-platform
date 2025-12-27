#!/usr/bin/env bash
set -e

LEDGER_DIR="apps/api/src/ledger"
LEDGER_SERVICE="$LEDGER_DIR/ledger.service.ts"

echo "==> Ledger klasoru garanti ediliyor"
mkdir -p "$LEDGER_DIR"

echo "==> LedgerService (Prisma-backed) yaziliyor"

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
