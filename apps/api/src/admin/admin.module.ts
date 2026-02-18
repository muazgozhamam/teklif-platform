import { Module } from '@nestjs/common';
import { AdminUsersModule } from './users/admin-users.module';
import { AdminLeadsModule } from './leads/admin-leads.module';
import { AdminPerformanceModule } from './performance/admin-performance.module';
import { AdminAuditModule } from './audit/admin-audit.module';
import { AdminOnboardingModule } from './onboarding/admin-onboarding.module';

@Module({
  imports: [AdminUsersModule, AdminLeadsModule, AdminPerformanceModule, AdminAuditModule, AdminOnboardingModule],
})
export class AdminModule {}
