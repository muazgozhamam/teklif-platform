import { Module } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { HunterLeadsController } from './hunter-leads.controller';

@Module({
  controllers: [HunterLeadsController],
  providers: [PrismaService],
})
export class HunterLeadsModule {}
