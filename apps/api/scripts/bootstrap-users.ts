import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import * as bcrypt from 'bcrypt';

async function bootstrap() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const prisma = app.get(PrismaService);

  // ---------- ADMIN ----------
  const adminEmail = 'admin@local.test';
  const adminExists = await prisma.user.findUnique({
    where: { email: adminEmail },
  });

  if (!adminExists) {
    await prisma.user.create({
      data: {
        email: adminEmail,
        password: await bcrypt.hash('123456', 10),
        name: 'Local Admin',
        role: 'ADMIN',
      },
    });
    console.log('✅ ADMIN created');
  } else {
    console.log('ℹ️ ADMIN already exists');
  }

  // ---------- CONSULTANT ----------
  const consultantEmail = 'consultant@local.test';
  const consultantExists = await prisma.user.findUnique({
    where: { email: consultantEmail },
  });

  if (!consultantExists) {
    await prisma.user.create({
      data: {
        email: consultantEmail,
        password: await bcrypt.hash('123456', 10),
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

bootstrap().catch(err => {
  console.error(err);
  process.exit(1);
});
