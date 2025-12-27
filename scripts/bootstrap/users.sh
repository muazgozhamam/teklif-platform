#!/usr/bin/env bash
set -e

echo "==> Bootstrapping ADMIN + CONSULTANT"

cd apps/api

pnpm ts-node <<'TS'
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../../apps/api/src/app.module';
import { PrismaService } from '../../apps/api/src/prisma/prisma.service';
import * as bcrypt from 'bcrypt';

async function bootstrap() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const prisma = app.get(PrismaService);

  const password = await bcrypt.hash('123456', 10);

  const adminEmail = 'admin@local.test';
  const consultantEmail = 'consultant@local.test';

  const admin = await prisma.user.findUnique({ where: { email: adminEmail } });
  if (!admin) {
    await prisma.user.create({
      data: {
        email: adminEmail,
        password,
        name: 'Local Admin',
        role: 'ADMIN',
      },
    });
    console.log('✅ ADMIN created');
  } else {
    console.log('ℹ️ ADMIN already exists');
  }

  const consultant = await prisma.user.findUnique({ where: { email: consultantEmail } });
  if (!consultant) {
    await prisma.user.create({
      data: {
        email: consultantEmail,
        password,
        name: 'Default Consultant',
        role: 'CONSULTANT',
      },
    });
    console.log('✅ CONSULTANT created');
  } else {
    console.log('ℹ️ CONSULTANT already exists');
  }

  await app.close();
}

bootstrap().catch(e => {
  console.error(e);
  process.exit(1);
});
TS

echo "✅ USERS BOOTSTRAP DONE"
