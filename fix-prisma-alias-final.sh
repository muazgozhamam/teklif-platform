#!/usr/bin/env bash
set -e

API=apps/api/src

echo "==> PrismaService importlari alias'a cekiliyor"

FILES=$(grep -rl "prisma.service" $API)

for f in $FILES; do
  perl -0777 -i -pe "
    s#from '\\.\\./prisma/prisma.service'#from '@/prisma/prisma.service'#g;
    s#from '\\.\\./\\.\\./prisma/prisma.service'#from '@/prisma/prisma.service'#g;
  " "$f"
done

echo "==> PrismaModule export garanti"

PRISMA_MOD=$API/prisma/prisma.module.ts

perl -0777 -i -pe '
  s/exports:\s*\[[^\]]*\]/exports: [PrismaService]/s;
  s/@Module\s*\(\s*\{([^}]*)\}\s*\)/@Module({$1, exports: [PrismaService]})/s unless /exports:/
' "$PRISMA_MOD"

echo "==> Build temizleniyor"
rm -rf apps/api/dist apps/api/.nest

echo "==> API build"
pnpm --filter api build

echo "==> API baslatiliyor"
node apps/api/dist/main.js &

echo "✅ TAMAM: Prisma alias + build tamamen duzeldi"
