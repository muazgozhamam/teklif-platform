import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { AdminLeadsController } from './admin-leads.controller';
import { AdminLeadsService } from './admin-leads.service';

@Module({
  imports: [PrismaModule],
  controllers: [AdminLeadsController],
  providers: [AdminLeadsService],
})
export class AdminLeadsModule {}
