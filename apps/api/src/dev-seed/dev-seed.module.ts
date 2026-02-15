import { Module, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcrypt';

// DEV amaçlı: E2E match akışının "No consultant available" ile takılmaması için
// uygulama açılışında 1 consultant garanti eder.
// NOT: Production'da kesinlikle çalışmaz (main.ts içinden sadece dev'de import edilir).
@Module({
  providers: [PrismaService],
})
export class DevSeedModule implements OnModuleInit {
  constructor(private readonly prisma: PrismaService) {}

  async onModuleInit() {
    const email = 'consultant1@test.com';
    const hash = await bcrypt.hash('pass123', 10);

    // Consultant var mı?
    const existing = await this.prisma.user.findFirst({
      where: { role: 'CONSULTANT' },
      orderBy: { createdAt: 'asc' },
      select: { id: true, email: true, role: true },
    });

    if (existing) {
      console.log(`[DEV-SEED] Consultant exists: ${existing.id} ${existing.email} ${existing.role}`);
      return;
    }

    // Yoksa oluştur (auth hash zorunluysa ileride burayı UserService üzerinden yaparız)
    const created = await this.prisma.user.upsert({
      where: { email },
      update: { role: 'CONSULTANT', isActive: true, password: hash },
      create: {
        email,
        password: hash,
        name: 'Consultant 1',
        role: 'CONSULTANT',
        isActive: true,
      },
      select: { id: true, email: true, role: true },
    });

    console.log(`[DEV-SEED] Consultant created: ${created.id} ${created.email} ${created.role}`);
  }
}
