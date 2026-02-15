import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../auth/jwt-auth.guard';
import { Roles } from '../../common/roles/roles.decorator';
import { RolesGuard } from '../../common/roles/roles.guard';
import { AdminKpiService } from './admin-kpi.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
@Controller('admin/kpi')
export class AdminKpiController {
  constructor(private readonly kpi: AdminKpiService) {}

  @Get('funnel')
  funnel(@Query('officeId') officeId?: string, @Query('regionId') regionId?: string) {
    return this.kpi.getFunnel({ officeId, regionId });
  }
}
