import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import * as bcrypt from 'bcrypt';

type BootstrapUser = {
  email: string;
  password: string;
  name: string;
  role: 'ADMIN' | 'CONSULTANT' | 'HUNTER' | 'BROKER';
};

async function bootstrap() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const prisma = app.get(PrismaService) as any;

  const users: BootstrapUser[] = [
    {
      email: 'admin@satdedi.com',
      password: 'SatDediAdmin!2026',
      name: 'SatDedi Admin',
      role: 'ADMIN',
    },
    {
      email: 'consultant@satdedi.com',
      password: 'SatDediConsultant!2026',
      name: 'SatDedi Danışman',
      role: 'CONSULTANT',
    },
    {
      email: 'hunter@satdedi.com',
      password: 'SatDediHunter!2026',
      name: 'SatDedi İş Ortağı',
      role: 'HUNTER',
    },
    {
      email: 'broker@satdedi.com',
      password: 'SatDediBroker!2026',
      name: 'SatDedi Broker',
      role: 'BROKER',
    },
  ];

  for (const user of users) {
    const exists = await prisma.user.findUnique({
      where: { email: user.email },
    });

    const passwordHash = await bcrypt.hash(user.password, 10);
    if (!exists) {
      await prisma.user.create({
        data: {
          email: user.email,
          password: passwordHash,
          name: user.name,
          role: user.role as any,
        },
      });
      console.log(`✅ ${user.role} created: ${user.email}`);
      continue;
    }

    await prisma.user.update({
      where: { email: user.email },
      data: {
        password: passwordHash,
        name: user.name,
        role: user.role as any,
      },
    });
    console.log(`♻️ ${user.role} updated: ${user.email}`);
  }

  await app.close();
}

bootstrap().catch(err => {
  console.error(err);
  process.exit(1);
});
