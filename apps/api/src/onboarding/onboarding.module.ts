import { Module } from '@nestjs/common';
import { AdminOnboardingController, OnboardingController } from './onboarding.controller';
import { OnboardingService } from './onboarding.service';

@Module({
  controllers: [OnboardingController, AdminOnboardingController],
  providers: [OnboardingService],
})
export class OnboardingModule {}
