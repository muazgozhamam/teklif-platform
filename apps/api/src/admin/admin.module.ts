import { Module } from '@nestjs/common';
import { AdminUsersModule } from './users/admin-users.module';
import { AdminLeadsModule } from './leads/admin-leads.module';

@Module({
  imports: [AdminUsersModule, AdminLeadsModule],
})
export class AdminModule {}
