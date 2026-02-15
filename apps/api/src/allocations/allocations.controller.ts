import { Body, Controller, Get, Param, Post, Query, Req, Res, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../common/roles/roles.decorator';
import { RolesGuard } from '../common/roles/roles.guard';
import { AllocationsService } from './allocations.service';
import type { Response } from 'express';

@Controller('admin/allocations')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AllocationsController {
  constructor(private readonly allocations: AllocationsService) {}

  @Get()
  list(
    @Query('take') take?: string,
    @Query('skip') skip?: string,
    @Query('snapshotId') snapshotId?: string,
    @Query('beneficiaryUserId') beneficiaryUserId?: string,
    @Query('state') state?: string,
  ) {
    return this.allocations.listAdmin({
      take: take ? Number(take) : undefined,
      skip: skip ? Number(skip) : undefined,
      snapshotId,
      beneficiaryUserId,
      state,
    });
  }

  @Post(':id/approve')
  approve(@Req() req: any, @Param('id') id: string) {
    return this.allocations.approve(id, {
      actorUserId: String(req.user?.sub ?? req.user?.id ?? '').trim() || null,
      actorRole: String(req.user?.role ?? '').trim().toUpperCase() || null,
    });
  }

  @Post(':id/void')
  void(@Req() req: any, @Param('id') id: string) {
    return this.allocations.void(id, {
      actorUserId: String(req.user?.sub ?? req.user?.id ?? '').trim() || null,
      actorRole: String(req.user?.role ?? '').trim().toUpperCase() || null,
    });
  }

  @Get('export.csv')
  async exportCsv(
    @Res({ passthrough: true }) res: Response,
    @Query('snapshotId') snapshotId?: string,
    @Query('beneficiaryUserId') beneficiaryUserId?: string,
    @Query('state') state?: string,
    @Query('onlyUnexported') onlyUnexported?: string,
  ) {
    const { csv } = await this.allocations.exportCsv({
      snapshotId,
      beneficiaryUserId,
      state: state || 'APPROVED',
      onlyUnexported: ['1', 'true', 'yes', 'on'].includes(String(onlyUnexported ?? '').toLowerCase()),
    });
    const stamp = new Date().toISOString().replaceAll(':', '-');
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename=\"allocations-${stamp}.csv\"`);
    return csv;
  }

  @Post('export/mark')
  markExported(
    @Req() req: any,
    @Body() body: { allocationIds?: string[]; exportBatchId?: string },
  ) {
    return this.allocations.markExported(
      body?.allocationIds ?? [],
      {
        actorUserId: String(req.user?.sub ?? req.user?.id ?? '').trim() || null,
        actorRole: String(req.user?.role ?? '').trim().toUpperCase() || null,
      },
      body?.exportBatchId ?? null,
    );
  }

  @Get('integrity/:snapshotId')
  integrity(@Param('snapshotId') snapshotId: string) {
    return this.allocations.validateSnapshotIntegrity(snapshotId);
  }
}
