import { Module } from '@nestjs/common';
import { AdminPerformanceController } from './admin-performance.controller';
import { AdminPerformanceService } from './admin-performance.service';

@Module({
  controllers: [AdminPerformanceController],
  providers: [AdminPerformanceService],
})
export class AdminPerformanceModule {}
