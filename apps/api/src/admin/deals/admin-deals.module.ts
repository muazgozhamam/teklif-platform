import { Module } from '@nestjs/common';
import { AdminDealsController } from './admin-deals.controller';
import { AdminDealsService } from './admin-deals.service';

@Module({
  controllers: [AdminDealsController],
  providers: [AdminDealsService],
})
export class AdminDealsModule {}

