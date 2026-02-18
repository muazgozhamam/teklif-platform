import { Controller, Get, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../common/roles/roles.decorator';
import { RolesGuard } from '../common/roles/roles.guard';
import { CommissionService } from './commission.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('HUNTER')
@Controller('hunter/commission')
export class HunterCommissionController {
  constructor(private readonly service: CommissionService) {}

  @Get('my')
  my(@Req() req: any) {
    return this.service.getMyCommission(String(req.user?.sub || ''), 'HUNTER');
  }
}
