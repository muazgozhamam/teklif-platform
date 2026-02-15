import { Controller, Get, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { StatsService } from './stats.service';

type ReqWithUser = {
  user?: { sub?: string; role?: string };
};

@UseGuards(JwtAuthGuard)
@Controller('stats')
export class StatsController {
  constructor(private readonly statsService: StatsService) {}

  @Get('me')
  me(@Req() req: ReqWithUser) {
    const userId = String(req.user?.sub || '').trim();
    const role = String(req.user?.role || '').trim().toUpperCase();
    return this.statsService.getMe(userId, role);
  }
}
