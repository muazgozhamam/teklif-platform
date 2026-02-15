import { Module } from '@nestjs/common';
import { DealsController } from './deals.controller';
import { DealsService } from './deals.service';
import { MatchingService } from './matching.service';
import { NetworkModule } from '../network/network.module';
import { AllocationsModule } from '../allocations/allocations.module';

@Module({
  imports: [NetworkModule, AllocationsModule],
  controllers: [DealsController],
  providers: [DealsService, MatchingService],
  exports: [DealsService],
})
export class DealsModule {}
