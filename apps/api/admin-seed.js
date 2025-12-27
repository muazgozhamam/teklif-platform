const bcrypt = require('bcryptjs');
const { NestFactory } = require('@nestjs/core');
const { AppModule } = require('./dist/src/app.module');
const { PrismaService } = require('./dist/src/prisma/prisma.service');

async function run() {
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: false,
  });

  const prisma = app.get(PrismaService);

  const email = 'admin@local.test';
  const pass = 'Admin12345!';

  const hash = await bcrypt.hash(pass, 10);

  const user = await prisma.user.upsert({
    where: { email },
    update: { password: hash, role: 'ADMIN', name: 'Local Admin' },
    create: { email, password: hash, role: 'ADMIN', name: 'Local Admin' },
  });

  console.log('OK admin ready:', {
    id: user.id,
    email: user.email,
    role: user.role,
  });

  await app.close();
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});

