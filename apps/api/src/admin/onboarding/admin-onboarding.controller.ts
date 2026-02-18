import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../auth/jwt-auth.guard';
import { Roles } from '../../common/roles/roles.decorator';
import { RolesGuard } from '../../common/roles/roles.guard';
import { AdminOnboardingService } from './admin-onboarding.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
@Controller('admin/onboarding')
export class AdminOnboardingController {
  constructor(private readonly service: AdminOnboardingService) {}

  @Get('users')
  users(
    @Query('role') role?: string,
    @Query('take') take?: string,
    @Query('skip') skip?: string,
  ) {
    return this.service.listUsers({ role, take, skip });
  }
}
