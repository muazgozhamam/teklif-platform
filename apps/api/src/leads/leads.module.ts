import { DealsModule } from '../deals/deals.module';
import { Module } from '@nestjs/common';
import { LeadsController } from './leads.controller';
import { LeadsService } from './leads.service';
import { BrokerLeadsController } from './broker-leads.controller';

@Module({
  imports: [DealsModule],
  controllers: [LeadsController,
    BrokerLeadsController],
  providers: [LeadsService],
})
export class LeadsModule {}
