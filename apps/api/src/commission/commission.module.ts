import { Module } from '@nestjs/common';
import { CommissionService } from './commission.service';
import { AdminCommissionController } from './admin-commission.controller';
import { BrokerCommissionController } from './broker-commission.controller';
import { ConsultantCommissionController } from './consultant-commission.controller';
import { HunterCommissionController } from './hunter-commission.controller';

@Module({
  providers: [CommissionService],
  controllers: [
    AdminCommissionController,
    BrokerCommissionController,
    ConsultantCommissionController,
    HunterCommissionController,
  ],
  exports: [CommissionService],
})
export class CommissionModule {}
