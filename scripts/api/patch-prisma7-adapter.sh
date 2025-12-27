#!/usr/bin/env bash
set -euo pipefail

# === MUST RUN FROM PROJECT ROOT ===
if [ ! -f "pnpm-workspace.yaml" ]; then
  echo "❌ HATA: Script proje kökünden çalıştırılmalıdır."
  echo "👉 cd ~/Desktop/teklif-platform"
  exit 1
fi

API_DIR="apps/api"

if [ ! -d "$API_DIR" ]; then
  echo "❌ HATA: apps/api bulunamadı."
  exit 1
fi

echo "==> [1/4] Adapter deps (pg + @prisma/adapter-pg) kuruluyor..."
cd "$API_DIR"
pnpm add pg @prisma/adapter-pg
pnpm add -D @types/pg

echo "==> [2/4] PrismaService (adapter ile) yazılıyor..."
mkdir -p src/prisma
cat > src/prisma/prisma.service.ts <<'TS'
import 'dotenv/config';
import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';

function getAdapter() {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error('DATABASE_URL is missing');
  return new PrismaPg({ connectionString: url });
}

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  constructor() {
    // Prisma 7: direct DB için adapter zorunlu
    super({ adapter: getAdapter() });
  }

  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
TS

echo "==> [3/4] Admin seed (adapter ile) yazılıyor..."
mkdir -p prisma/seed
cat > prisma/seed/admin.js <<'JS'
require('dotenv/config');

const bcrypt = require('bcrypt');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');

function getAdapter() {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error('DATABASE_URL is missing');
  return new PrismaPg({ connectionString: url });
}

const prisma = new PrismaClient({ adapter: getAdapter() });

async function main() {
  const email = 'admin@local.dev';
  const password = await bcrypt.hash('admin123', 10);

  await prisma.user.upsert({
    where: { email },
    update: {},
    create: { email, password, role: 'ADMIN' },
  });

  console.log('✅ Admin user hazır:', email, ' / admin123');
}

main()
  .catch((e) => {
    console.error('SEED ERROR:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
JS

node - <<'NODE'
const fs = require('fs');
const pkgPath = 'package.json';
const pkg = JSON.parse(fs.readFileSync(pkgPath,'utf8'));
pkg.scripts = pkg.scripts || {};
pkg.scripts["db:seed"] = "node prisma/seed/admin.js";
fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2));
console.log("OK: db:seed -> node prisma/seed/admin.js");
NODE

echo "==> [4/4] Seed çalıştırılıyor..."
pnpm db:seed

echo "✅ Prisma 7 adapter fix tamam."
echo "Şimdi API:"
echo "  cd apps/api && pnpm start:dev"
echo "Login test:"
echo "  curl -s -X POST http://localhost:3001/auth/login -H 'Content-Type: application/json' -d '{\"email\":\"admin@local.dev\",\"password\":\"admin123\"}'"
