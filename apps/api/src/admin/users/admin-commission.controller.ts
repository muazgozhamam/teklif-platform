import { Body, Controller, Get, Patch, Req, UseGuards } from '@nestjs/common';
import { Roles } from '../../common/roles/roles.decorator';
import { RolesGuard } from '../../common/roles/roles.guard';
import { JwtAuthGuard } from '../../auth/jwt-auth.guard';
import { AdminUsersService } from './admin-users.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
@Controller('admin/commission-config')
export class AdminCommissionController {
  constructor(private users: AdminUsersService) {}

  private actor(req: { user?: { sub?: string; id?: string; role?: string } }) {
    return {
      actorUserId: String(req?.user?.sub ?? req?.user?.id ?? '').trim() || null,
      actorRole: String(req?.user?.role ?? '').trim().toUpperCase() || null,
    };
  }

  @Get()
  getConfig() {
    return this.users.getCommissionConfig();
  }

  @Patch()
  patchConfig(
    @Req() req: any,
    @Body()
    body: {
      baseRate?: number;
      hunterSplit?: number;
      brokerSplit?: number;
      consultantSplit?: number;
      platformSplit?: number;
    },
  ) {
    return this.users.patchCommissionConfig(body, this.actor(req));
  }
}
