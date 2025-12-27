import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { OffersService } from './offers.service';
import { OffersController } from './offers.controller';
import { AdminOffersController } from './admin-offers.controller';

@Module({
  imports: [PrismaModule],
  controllers: [OffersController, AdminOffersController],
  providers: [OffersService],
})
export class OffersModule {}
