import { Module } from '@nestjs/common';
import { AdminTrustController } from './trust.controller';
import { TrustService } from './trust.service';

@Module({
  controllers: [AdminTrustController],
  providers: [TrustService],
  exports: [TrustService],
})
export class TrustModule {}
