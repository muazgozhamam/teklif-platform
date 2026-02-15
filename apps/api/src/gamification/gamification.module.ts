import { Module } from '@nestjs/common';
import { AdminGamificationController, GamificationController } from './gamification.controller';
import { GamificationService } from './gamification.service';

@Module({
  controllers: [GamificationController, AdminGamificationController],
  providers: [GamificationService],
  exports: [GamificationService],
})
export class GamificationModule {}
