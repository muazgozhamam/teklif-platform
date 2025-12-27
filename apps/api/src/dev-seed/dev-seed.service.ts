import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Role } from '@prisma/client';

@Injectable()
export class DevSeedService implements OnModuleInit {
  private readonly logger = new Logger(DevSeedService.name);

  constructor(private readonly prisma: PrismaService) {}

  async onModuleInit() {
    if (process.env.DEV_SEED !== '1') {
      return;
    }

    // DEV amaçlı consultant seed (idempotent)
    const id = 'consultant_seed_1';
    const email = 'consultant1@test.com';

    try {
      await this.prisma.user.upsert({
        where: { email },
        update: { role: Role.CONSULTANT },
        create: {
          id,
          email,
          password: 'pass123',
          name: 'Consultant 1',
          role: Role.CONSULTANT,
        },
      });

      this.logger.log(`DEV seed OK: consultant ensured (${email})`);
    } catch (e: any) {
      this.logger.warn(`DEV seed skipped/failed: ${e?.message ?? e}`);
    }
  }
}
