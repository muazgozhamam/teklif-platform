import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ConfigModule, ConfigService } from '@nestjs/config';
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
import { StatsModule } from './stats/stats.module';
import { AuditModule } from './audit/audit.module';
import { CommissionsModule } from './commissions/commissions.module';
import { AllocationsModule } from './allocations/allocations.module';
import { ObservabilityModule } from './observability/observability.module';
import { GamificationModule } from './gamification/gamification.module';
import { TrustModule } from './trust/trust.module';
import { OnboardingModule } from './onboarding/onboarding.module';
import { SimpleRateLimitGuard } from './common/rate-limit/simple-rate-limit.guard';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env', 'apps/api/.env'],
    }),
    JwtModule.registerAsync({
      global: true,
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => ({
        secret: cfg.get<string>('JWT_SECRET') || 'dev-secret',
        signOptions: { expiresIn: 900 },
      }),
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
    StatsModule,
    ObservabilityModule,
    AuditModule,
    CommissionsModule,
    AllocationsModule,
    GamificationModule,
    TrustModule,
    OnboardingModule,
  ],
  providers: [
    {
      provide: APP_GUARD,
      useClass: SimpleRateLimitGuard,
    },
  ],
})
export class AppModule {}
