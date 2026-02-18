import { Controller, Get, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../common/roles/roles.decorator';
import { RolesGuard } from '../common/roles/roles.guard';
import { CommissionService } from './commission.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('CONSULTANT')
@Controller('consultant/commission')
export class ConsultantCommissionController {
  constructor(private readonly service: CommissionService) {}

  @Get('my')
  my(@Req() req: any) {
    return this.service.getMyCommission(String(req.user?.sub || ''), 'CONSULTANT');
  }
}
