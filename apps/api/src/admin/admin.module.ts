import { Module } from '@nestjs/common';
import { AdminUsersModule } from './users/admin-users.module';
import { AdminLeadsModule } from './leads/admin-leads.module';
import { AdminPerformanceModule } from './performance/admin-performance.module';

@Module({
  imports: [AdminUsersModule, AdminLeadsModule, AdminPerformanceModule],
})
export class AdminModule {}
