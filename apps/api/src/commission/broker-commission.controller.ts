import { Body, Controller, Get, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../common/roles/roles.decorator';
import { RolesGuard } from '../common/roles/roles.guard';
import { CommissionService } from './commission.service';
import { ApproveSnapshotDto } from './dto/approve-snapshot.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('BROKER')
@Controller('broker/commission')
export class BrokerCommissionController {
  constructor(private readonly service: CommissionService) {}

  @Get('pending-approvals')
  pending(@Query('from') from?: string, @Query('to') to?: string) {
    return this.service.getPendingApprovals(from, to);
  }

  @Post('snapshots/:snapshotId/approve')
  approve(@Req() req: any, @Param('snapshotId') snapshotId: string, @Body() body: ApproveSnapshotDto) {
    return this.service.approveSnapshot(String(req.user?.sub || ''), String(req.user?.role || ''), snapshotId, body || {});
  }
}
