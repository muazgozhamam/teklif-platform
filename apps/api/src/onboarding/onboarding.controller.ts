import { Controller, Get, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../common/roles/roles.decorator';
import { RolesGuard } from '../common/roles/roles.guard';
import { OnboardingService } from './onboarding.service';

@UseGuards(JwtAuthGuard)
@Controller('onboarding')
export class OnboardingController {
  constructor(private readonly onboarding: OnboardingService) {}

  @Get('me')
  me(@Req() req: any) {
    const userId = String(req.user?.sub ?? req.user?.id ?? '').trim();
    return this.onboarding.getUserOnboarding(userId);
  }
}

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
@Controller('admin/onboarding')
export class AdminOnboardingController {
  constructor(private readonly onboarding: OnboardingService) {}

  @Get('users')
  list(@Query('role') role?: string, @Query('take') take?: string, @Query('skip') skip?: string) {
    return this.onboarding.listOnboarding(role, take ? Number(take) : undefined, skip ? Number(skip) : undefined);
  }
}
