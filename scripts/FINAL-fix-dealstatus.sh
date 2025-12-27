#!/usr/bin/env bash
set -e

FILE="apps/api/src/deals/deals.service.ts"
API_DIR="apps/api"

echo "==> FINAL fixing DealStatus"

node <<'NODE'
const fs = require('fs');

const file = 'apps/api/src/deals/deals.service.ts';
let src = fs.readFileSync(file, 'utf8');

/**
 * 1) DealStatus importunu DOSYANIN EN BAŞINA ZORLA EKLE
 */
if (!src.includes("DealStatus")) {
  src = `import { DealStatus } from '@prisma/client';\n` + src;
}

/**
 * 2) status: "READY" → DealStatus.READY
 */
src = src.replace(/status:\s*["']READY["']/g, 'status: DealStatus.READY');

/**
 * 3) status: event → enum map
 */
src = src.replace(
  /status:\s*event/g,
  'status: DealStatus[event as keyof typeof DealStatus]'
);

fs.writeFileSync(file, src, 'utf8');
console.log('✅ DealStatus import + usage fixed');
NODE

echo "==> Build API"
cd "$API_DIR"
pnpm -s build

echo "✅ DONE"
