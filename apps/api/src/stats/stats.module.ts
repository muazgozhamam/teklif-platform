import { Module } from '@nestjs/common';
import { StatsController } from './stats.controller';
import { StatsService } from './stats.service';
import { StatsCacheService } from './stats-cache.service';

@Module({
  controllers: [StatsController],
  providers: [StatsService, StatsCacheService],
})
export class StatsModule {}
