import { Body, Controller, Get, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../common/roles/roles.decorator';
import { RolesGuard } from '../common/roles/roles.guard';
import { CommissionService } from './commission.service';
import { CreateSnapshotDto } from './dto/create-snapshot.dto';
import { ApproveSnapshotDto } from './dto/approve-snapshot.dto';
import { ReverseSnapshotDto } from './dto/reverse-snapshot.dto';
import { CreatePayoutDto } from './dto/create-payout.dto';
import { CreateDisputeDto } from './dto/create-dispute.dto';
import { UpdateDisputeStatusDto } from './dto/update-dispute-status.dto';
import { CreatePeriodLockDto } from './dto/create-period-lock.dto';
import { ReleasePeriodLockDto } from './dto/release-period-lock.dto';

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

  @Get('disputes')
  disputes(@Query('status') status?: string) {
    return this.service.listDisputes(status);
  }

  @Post('disputes')
  createDispute(@Req() req: any, @Body() body: CreateDisputeDto) {
    return this.service.createDispute(String(req.user?.sub || ''), body);
  }

  @Post('disputes/:disputeId/status')
  updateDisputeStatus(@Req() req: any, @Param('disputeId') disputeId: string, @Body() body: UpdateDisputeStatusDto) {
    return this.service.updateDisputeStatus(String(req.user?.sub || ''), disputeId, body);
  }

  @Post('disputes/:disputeId/resolve')
  resolveDispute(@Req() req: any, @Param('disputeId') disputeId: string, @Body() body: UpdateDisputeStatusDto) {
    return this.service.updateDisputeStatus(String(req.user?.sub || ''), disputeId, body);
  }

  @Get('period-locks')
  periodLocks() {
    return this.service.listPeriodLocks();
  }

  @Post('period-locks')
  createPeriodLock(@Req() req: any, @Body() body: CreatePeriodLockDto) {
    return this.service.createPeriodLock(String(req.user?.sub || ''), body);
  }

  @Post('period-locks/:lockId/release')
  releasePeriodLock(@Req() req: any, @Param('lockId') lockId: string, @Body() body: ReleasePeriodLockDto) {
    return this.service.releasePeriodLock(String(req.user?.sub || ''), lockId, body || {});
  }

  @Post('disputes/escalate-overdue')
  escalateOverdue(@Req() req: any) {
    return this.service.escalateOverdueDisputes(String(req.user?.sub || 'system'));
  }
}
