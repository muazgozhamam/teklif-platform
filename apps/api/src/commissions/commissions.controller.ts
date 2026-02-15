import { Controller, Get, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../common/roles/roles.decorator';
import { RolesGuard } from '../common/roles/roles.guard';
import { CommissionsService } from './commissions.service';

@Controller()
export class CommissionsController {
  constructor(private readonly commissions: CommissionsService) {}

  private getUserId(req: any) {
    return String(req?.user?.sub ?? req?.user?.id ?? req?.headers?.['x-user-id'] ?? '').trim();
  }

  @Get('me/commissions')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('CONSULTANT')
  myCommissions(
    @Req() req: any,
    @Query('take') take?: string,
    @Query('skip') skip?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('status') status?: string,
  ) {
    return this.commissions.listMine(this.getUserId(req), {
      take: take ? Number(take) : undefined,
      skip: skip ? Number(skip) : undefined,
      from,
      to,
      status,
    });
  }

  @Get('broker/commissions')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('BROKER', 'ADMIN')
  brokerCommissions(
    @Query('take') take?: string,
    @Query('skip') skip?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('consultantId') consultantId?: string,
  ) {
    return this.commissions.listBroker({
      take: take ? Number(take) : undefined,
      skip: skip ? Number(skip) : undefined,
      from,
      to,
      consultantId,
    });
  }

  @Get('admin/commissions')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  adminCommissions(
    @Query('take') take?: string,
    @Query('skip') skip?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('q') q?: string,
    @Query('officeId') officeId?: string,
    @Query('regionId') regionId?: string,
  ) {
    return this.commissions.listAdmin({
      take: take ? Number(take) : undefined,
      skip: skip ? Number(skip) : undefined,
      from,
      to,
      q,
      officeId,
      regionId,
    });
  }
}
