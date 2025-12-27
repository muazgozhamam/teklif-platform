#!/usr/bin/env bash
set -e

ROOT_DIR="$(pwd)"
API_DIR="$ROOT_DIR/apps/api"
FILE="$API_DIR/src/deals/deals.service.ts"
TS="$(date +%Y%m%d-%H%M%S)"

echo "==> Patch matchDeal: CONSULTANT only"

if [ ! -f "$FILE" ]; then
  echo "❌ deals.service.ts not found at $FILE"
  exit 1
fi

cp "$FILE" "$FILE.bak.$TS"
echo "🗂 Backup created: deals.service.ts.bak.$TS"

node <<'NODE'
const fs = require('fs');
const path = require('path');

const file = path.resolve(process.cwd(), 'apps/api/src/deals/deals.service.ts');
let src = fs.readFileSync(file, 'utf8');

if (!src.includes('matchDeal')) {
  console.error('❌ matchDeal not found');
  process.exit(1);
}

if (!src.includes('Role.CONSULTANT')) {
  src = src.replace(
    /this\\.prisma\\.user\\.findFirst\\([\\s\\S]*?\\)/,
    `this.prisma.user.findFirst({
      where: { role: Role.CONSULTANT },
      orderBy: { createdAt: 'asc' },
    })`
  );
}

fs.writeFileSync(file, src, 'utf8');
console.log('✅ matchDeal patched (CONSULTANT only)');
NODE

echo "==> Build"
cd "$API_DIR"
pnpm -s build

echo "✅ DONE"
