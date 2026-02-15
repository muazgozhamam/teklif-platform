import { Controller, Get, Post, Query, Req, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../common/roles/roles.decorator';
import { RolesGuard } from '../common/roles/roles.guard';
import { TrustService } from './trust.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
@Controller('admin/trust')
export class AdminTrustController {
  constructor(private readonly trust: TrustService) {}

  @Get('users')
  listUsers(@Query('take') take?: string, @Query('skip') skip?: string, @Query('role') roleRaw?: string, @Query('userId') userId?: string) {
    const role = String(roleRaw ?? '').trim().toUpperCase() as Role;
    const allowed = new Set<Role>([Role.ADMIN, Role.BROKER, Role.CONSULTANT, Role.HUNTER, Role.USER]);
    return this.trust.listTrust({
      take: take ? Number(take) : undefined,
      skip: skip ? Number(skip) : undefined,
      role: allowed.has(role) ? role : undefined,
      userId,
    });
  }

  @Post('users/review')
  review(@Req() req: any, @Query('userId') userId?: string) {
    const actorUserId = String(req.user?.sub ?? req.user?.id ?? '').trim() || null;
    return this.trust.markReviewedByAdmin(String(userId ?? ''), actorUserId);
  }
}
