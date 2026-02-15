import { Module } from '@nestjs/common';
import { AdminUsersService } from './admin-users.service';
import { AdminUsersController } from './admin-users.controller';
import { AdminCommissionController } from './admin-commission.controller';

@Module({
  providers: [AdminUsersService],
  controllers: [AdminUsersController, AdminCommissionController],
})
export class AdminUsersModule {}
