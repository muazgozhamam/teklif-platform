import { BadRequestException, Body, Controller, Get, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../../auth/jwt-auth.guard';
import { Roles } from '../../common/roles/roles.decorator';
import { RolesGuard } from '../../common/roles/roles.guard';
import { NetworkService } from '../../network/network.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
@Controller('admin/network')
export class AdminNetworkController {
  constructor(private readonly network: NetworkService) {}

  @Post('parent')
  setParent(
    @Req() req: any,
    @Body() body: { childId: string; parentId: string },
  ) {
    return this.network.setParent(body.childId, body.parentId, this.actor(req));
  }

  @Get(':userId/path')
  getPath(@Param('userId') userId: string) {
    return this.network.getNetworkPath(userId);
  }

  @Get(':userId/upline')
  getUpline(@Param('userId') userId: string, @Query('maxDepth') maxDepth?: string) {
    return this.network.getUpline(userId, maxDepth ? Number(maxDepth) : undefined);
  }

  @Post('commission-split')
  setCommissionSplit(
    @Req() req: any,
    @Body() body: { role: Role | string; percent: number },
  ) {
    return this.network.setCommissionSplit(this.parseRole(body.role), Number(body.percent), this.actor(req));
  }

  @Get('commission-split')
  getCommissionSplitMap() {
    return this.network.getSplitMap();
  }

  private actor(req: { user?: { sub?: string; id?: string; role?: string } }) {
    return {
      actorUserId: String(req?.user?.sub ?? req?.user?.id ?? '').trim() || null,
      actorRole: String(req?.user?.role ?? '').trim().toUpperCase() || null,
    };
  }

  private parseRole(role: Role | string): Role {
    const value = String(role ?? '').trim().toUpperCase();
    if (!Object.values(Role).includes(value as Role)) {
      throw new BadRequestException('Invalid role');
    }
    return value as Role;
  }
}
