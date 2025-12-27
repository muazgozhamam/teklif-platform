#!/usr/bin/env bash
set -euo pipefail

FILE="apps/api/src/admin/leads/admin-leads.module.ts"
if [ ! -f "$FILE" ]; then
  echo "HATA: $FILE bulunamadı."
  exit 1
fi

echo "==> Fixing: $FILE (ensure AdminLeadsService provider)"

cat > "$FILE" <<'EOF'
import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { AdminLeadsController } from './admin-leads.controller';
import { AdminLeadsService } from './admin-leads.service';

@Module({
  imports: [PrismaModule],
  controllers: [AdminLeadsController],
  providers: [AdminLeadsService],
})
export class AdminLeadsModule {}
EOF

echo "==> DONE. Restart API."
