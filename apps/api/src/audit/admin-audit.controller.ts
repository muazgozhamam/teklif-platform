import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../common/roles/roles.decorator';
import { RolesGuard } from '../common/roles/roles.guard';
import { AuditService } from './audit.service';

@Controller('admin/audit')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminAuditController {
  constructor(private readonly audit: AuditService) {}

  @Get()
  list(
    @Query('take') take?: string,
    @Query('skip') skip?: string,
    @Query('entityType') entityType?: string,
    @Query('entityId') entityId?: string,
    @Query('actorUserId') actorUserId?: string,
    @Query('action') action?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('q') q?: string,
  ) {
    return this.audit.listAdmin({
      take: take ? Number(take) : undefined,
      skip: skip ? Number(skip) : undefined,
      entityType,
      entityId,
      actorUserId,
      action,
      from,
      to,
      q,
    });
  }

  @Get('integrity')
  integrity(
    @Query('take') take?: string,
    @Query('skip') skip?: string,
  ) {
    return this.audit.integrityReport({
      take: take ? Number(take) : undefined,
      skip: skip ? Number(skip) : undefined,
    });
  }
}
