import { Module } from '@nestjs/common';
import { AdminUsersModule } from './users/admin-users.module';
import { AdminLeadsModule } from './leads/admin-leads.module';
import { AdminNetworkModule } from './network/admin-network.module';
import { AdminOrgModule } from './org/admin-org.module';
import { AdminDealsModule } from './deals/admin-deals.module';
import { AdminJobsModule } from './jobs/admin-jobs.module';
import { AdminKpiModule } from './kpi/admin-kpi.module';

@Module({
  imports: [AdminUsersModule, AdminLeadsModule, AdminNetworkModule, AdminOrgModule, AdminDealsModule, AdminJobsModule, AdminKpiModule],
})
export class AdminModule {}
