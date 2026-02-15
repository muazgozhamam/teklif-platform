import { Controller, Get, Query, Req, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../common/roles/roles.decorator';
import { RolesGuard } from '../common/roles/roles.guard';
import { GamificationService } from './gamification.service';

@UseGuards(JwtAuthGuard)
@Controller('gamification')
export class GamificationController {
  constructor(private readonly gamification: GamificationService) {}

  @Get('me')
  me(@Req() req: any) {
    const userId = String(req.user?.sub ?? req.user?.id ?? '').trim();
    const role = String(req.user?.role ?? '').trim().toUpperCase();
    return this.gamification.getMyProfile(userId, role);
  }
}

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
@Controller('admin/gamification')
export class AdminGamificationController {
  constructor(private readonly gamification: GamificationService) {}

  @Get('leaderboard')
  leaderboard(@Query('role') roleRaw?: string, @Query('take') take?: string, @Query('skip') skip?: string) {
    const role = String(roleRaw ?? '').trim().toUpperCase() as Role;
    const allowed = new Set<Role>([Role.HUNTER, Role.CONSULTANT, Role.BROKER]);
    const safeRole = allowed.has(role) ? role : Role.HUNTER;
    return this.gamification.getLeaderboard({
      role: safeRole,
      take: take ? Number(take) : undefined,
      skip: skip ? Number(skip) : undefined,
    });
  }
}
