import { Body, Controller, Get, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../common/roles/roles.decorator';
import { RolesGuard } from '../common/roles/roles.guard';
import { CommissionService } from './commission.service';
import { CreateSnapshotDto } from './dto/create-snapshot.dto';
import { ApproveSnapshotDto } from './dto/approve-snapshot.dto';
import { ReverseSnapshotDto } from './dto/reverse-snapshot.dto';
import { CreatePayoutDto } from './dto/create-payout.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
@Controller('admin/commission')
export class AdminCommissionController {
  constructor(private readonly service: CommissionService) {}

  @Post('snapshots')
  createSnapshot(@Req() req: any, @Body() body: CreateSnapshotDto) {
    return this.service.createSnapshot(String(req.user?.sub || ''), body);
  }

  @Get('pending-approvals')
  pending(@Query('from') from?: string, @Query('to') to?: string) {
    return this.service.getPendingApprovals(from, to);
  }

  @Post('snapshots/:snapshotId/approve')
  approve(@Req() req: any, @Param('snapshotId') snapshotId: string, @Body() body: ApproveSnapshotDto) {
    return this.service.approveSnapshot(String(req.user?.sub || ''), String(req.user?.role || ''), snapshotId, body || {});
  }

  @Post('snapshots/:snapshotId/reverse')
  reverse(@Req() req: any, @Param('snapshotId') snapshotId: string, @Body() body: ReverseSnapshotDto) {
    return this.service.reverseSnapshot(String(req.user?.sub || ''), snapshotId, body);
  }

  @Post('payouts')
  payout(@Req() req: any, @Body() body: CreatePayoutDto) {
    return this.service.createPayout(String(req.user?.sub || ''), body);
  }

  @Get('overview')
  overview(@Query('from') from?: string, @Query('to') to?: string) {
    return this.service.getOverview(from, to);
  }

  @Get('deals/:dealId')
  dealDetail(@Param('dealId') dealId: string) {
    return this.service.getDealDetail(dealId);
  }
}
