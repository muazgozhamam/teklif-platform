import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../auth/jwt-auth.guard';
import { Roles } from '../../common/roles/roles.decorator';
import { RolesGuard } from '../../common/roles/roles.guard';
import { AdminLeaderboardsService } from './admin-leaderboards.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
@Controller('admin/leaderboards')
export class AdminLeaderboardsController {
  constructor(private readonly service: AdminLeaderboardsService) {}

  @Get()
  list(
    @Query('role') role?: 'HUNTER' | 'CONSULTANT' | 'BROKER',
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.service.getLeaderboards(role, from, to);
  }
}
