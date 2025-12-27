import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { ListingsController } from './listings.controller';
import { ListingsService } from './listings.service';
import { ConsultantGuard } from './consultant.guard';

@Module({
  imports: [PrismaModule],
  controllers: [ListingsController],
  providers: [ListingsService, ConsultantGuard],
  exports: [ListingsService],
})
export class ListingsModule {}
