import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../auth/jwt-auth.guard';
import { Roles } from '../../common/roles/roles.decorator';
import { RolesGuard } from '../../common/roles/roles.guard';
import { AdminDealsService } from './admin-deals.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
@Controller('admin/deals')
export class AdminDealsController {
  constructor(private readonly deals: AdminDealsService) {}

  @Get()
  list(
    @Query('take') take?: string,
    @Query('skip') skip?: string,
    @Query('officeId') officeId?: string,
    @Query('regionId') regionId?: string,
  ) {
    return this.deals.list({
      take: take ? Number(take) : undefined,
      skip: skip ? Number(skip) : undefined,
      officeId,
      regionId,
    });
  }
}

