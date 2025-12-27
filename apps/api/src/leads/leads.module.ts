import { DealsModule } from '../deals/deals.module';
import { Module } from '@nestjs/common';
import { LeadsController } from './leads.controller';
import { LeadsService } from './leads.service';

@Module({
  imports: [DealsModule],
  controllers: [LeadsController],
  providers: [LeadsService],
})
export class LeadsModule {}
