import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../auth/jwt-auth.guard';
import { Roles } from '../../common/roles/roles.decorator';
import { RolesGuard } from '../../common/roles/roles.guard';
import { AdminAuditService } from './admin-audit.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
@Controller('admin/audit')
export class AdminAuditController {
  constructor(private readonly service: AdminAuditService) {}

  @Get()
  list(
    @Query('q') q?: string,
    @Query('action') action?: string,
    @Query('entityType') entityType?: string,
    @Query('take') take?: string,
    @Query('skip') skip?: string,
  ) {
    return this.service.list({ q, action, entityType, take, skip });
  }
}
