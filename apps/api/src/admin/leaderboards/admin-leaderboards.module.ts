import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { AdminLeaderboardsController } from './admin-leaderboards.controller';
import { AdminLeaderboardsService } from './admin-leaderboards.service';

@Module({
  imports: [PrismaModule],
  controllers: [AdminLeaderboardsController],
  providers: [AdminLeaderboardsService],
})
export class AdminLeaderboardsModule {}
