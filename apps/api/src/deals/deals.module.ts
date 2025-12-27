import { Module } from '@nestjs/common';
import { DealsController } from './deals.controller';
import { DealsService } from './deals.service';
import { MatchingService } from './matching.service';

@Module({
  controllers: [DealsController],
  providers: [DealsService, MatchingService],
  exports: [DealsService],
})
export class DealsModule {}
