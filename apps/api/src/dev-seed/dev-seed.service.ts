import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';

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
    const hash = await bcrypt.hash('pass123', 10);

    try {
      await this.prisma.user.upsert({
        where: { email },
        update: { role: Role.CONSULTANT, isActive: true, password: hash },
        create: {
          id,
          email,
          password: hash,
          name: 'Consultant 1',
          role: Role.CONSULTANT,
          isActive: true,
        },
      });

      this.logger.log(`DEV seed OK: consultant ensured (${email})`);
    } catch (e: any) {
      this.logger.warn(`DEV seed skipped/failed: ${e?.message ?? e}`);
    }
  }
}
