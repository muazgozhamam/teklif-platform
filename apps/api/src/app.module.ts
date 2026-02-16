import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';

import { PrismaModule } from './prisma/prisma.module';
import { HealthModule } from './health/health.module';
import { AuthModule } from './auth/auth.module';
import { AdminModule } from './admin/admin.module';
import { LeadsModule } from './leads/leads.module';
import { HunterLeadsModule } from './hunter-leads/hunter-leads.module';
import { DealsModule } from './deals/deals.module';
import { ListingsModule } from './listings/listings.module';
import { DevSeedModule } from './dev-seed/dev-seed.module';
import { PublicModule } from './public/public.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env', 'apps/api/.env'],
    }),
    JwtModule.register({
      global: true,
      secret: process.env.JWT_SECRET || 'dev-secret',
      signOptions: { expiresIn: '7d' },
    }),
    PrismaModule,
    HealthModule,
    AuthModule,
    AdminModule,
    LeadsModule,
    HunterLeadsModule,
    DealsModule,
    ListingsModule,
    DevSeedModule,
    PublicModule,
  ],
})
export class AppModule {}
