#!/usr/bin/env bash
set -e

API_DIR="apps/api"
FILE="$API_DIR/src/deals/deals.service.ts"

echo "==> FORCE fixing DealStatus issue"

node <<'NODE'
const fs = require('fs');

const file = 'apps/api/src/deals/deals.service.ts';
let src = fs.readFileSync(file, 'utf8');

/**
 * 1) @prisma/client importunu ZORLA düzelt
 * Ne varsa sil, yerine bunu koy
 */
src = src.replace(
  /import\s+\{[\s\S]*?\}\s+from\s+'@prisma\/client';/,
  "import { DealStatus } from '@prisma/client';"
);

/**
 * 2) advanceDeal içindeki status atamalarını ZORLA enum yap
 */
src = src.replace(/status:\s*["']READY["']/g, 'status: DealStatus.READY');

src = src.replace(
  /status:\s*event/g,
  'status: DealStatus[event as keyof typeof DealStatus]'
);

fs.writeFileSync(file, src, 'utf8');
console.log('✅ DealStatus FORCE fixed');
NODE

echo "==> Build API"
cd "$API_DIR"
pnpm -s build

echo "✅ DONE"
