import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../auth/jwt-auth.guard';
import { Roles } from '../../common/roles/roles.decorator';
import { RolesGuard } from '../../common/roles/roles.guard';
import { AdminJobsService } from './admin-jobs.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
@Controller('admin/jobs')
export class AdminJobsController {
  constructor(private readonly jobs: AdminJobsService) {}

  @Get('runs')
  listRuns(
    @Query('take') take?: string,
    @Query('skip') skip?: string,
    @Query('jobName') jobName?: string,
    @Query('status') status?: string,
  ) {
    return this.jobs.listRuns({
      take: take ? Number(take) : undefined,
      skip: skip ? Number(skip) : undefined,
      jobName,
      status,
    });
  }

  @Post('allocation-integrity')
  runAllocationIntegrity(@Body() body: { snapshotId?: string; idempotencyKey?: string }) {
    return this.jobs.runAllocationIntegrityJob({
      snapshotId: String(body?.snapshotId ?? '').trim(),
      idempotencyKey: body?.idempotencyKey,
    });
  }
}
