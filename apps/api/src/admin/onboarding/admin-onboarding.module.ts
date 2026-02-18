import { Module } from '@nestjs/common';
import { AdminOnboardingController } from './admin-onboarding.controller';
import { AdminOnboardingService } from './admin-onboarding.service';

@Module({
  controllers: [AdminOnboardingController],
  providers: [AdminOnboardingService],
})
export class AdminOnboardingModule {}
