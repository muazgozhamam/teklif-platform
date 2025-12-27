import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { HealthModule } from './health/health.module';
import { AuthModule } from './auth/auth.module';
import { AdminModule } from './admin/admin.module';
import { LeadsModule } from './leads/leads.module';
import { DealsModule } from './deals/deals.module';
import { ListingsModule } from './listings/listings.module';
import { DevSeedModule } from './dev-seed/dev-seed.module';
@Module({
imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    HealthModule,
    AuthModule,
    AdminModule,
    LeadsModule,
    DealsModule,
  
    ListingsModule,
  DevSeedModule,
],
})
export class AppModule {}
