import { Module } from '@nestjs/common';
import { AdminKpiController } from './admin-kpi.controller';
import { AdminKpiService } from './admin-kpi.service';

@Module({
  controllers: [AdminKpiController],
  providers: [AdminKpiService],
})
export class AdminKpiModule {}
