import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../common/roles/roles.decorator';
import { RolesGuard } from '../common/roles/roles.guard';
import { ApplicationsService } from './applications.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
@Controller('admin/applications')
export class AdminApplicationsController {
  constructor(private readonly applications: ApplicationsService) {}

  @Get('overview')
  overview() {
    return this.applications.getOverview();
  }

  @Get()
  list(
    @Query('type') type?: string,
    @Query('status') status?: string,
    @Query('q') q?: string,
    @Query('assignedTo') assignedTo?: string,
    @Query('priority') priority?: string,
    @Query('take') take?: string,
    @Query('skip') skip?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.applications.listForAdmin({
      type,
      status,
      q,
      assignedTo,
      priority,
      take: take ? Number(take) : undefined,
      skip: skip ? Number(skip) : undefined,
      from,
      to,
    });
  }

  @Get(':id')
  getOne(@Param('id') id: string) {
    return this.applications.getOneForAdmin(id);
  }

  @Patch(':id')
  patch(
    @Param('id') id: string,
    @Body() body: Record<string, unknown>,
    @Req() req: Request & { user?: { sub?: string } },
  ) {
    return this.applications.patchForAdmin(
      id,
      {
        status: body?.status as any,
        priority: body?.priority as any,
        assignedToUserId: (body?.assignedToUserId as string | null | undefined) ?? undefined,
        tags: Array.isArray(body?.tags) ? body.tags.map((t) => String(t)) : undefined,
        notes: typeof body?.notes === 'string' ? body.notes : undefined,
      },
      req.user?.sub,
    );
  }

  @Post(':id/notes')
  addNote(
    @Param('id') id: string,
    @Body() body: { body?: string },
    @Req() req: Request & { user?: { sub?: string } },
  ) {
    return this.applications.addNote(id, req.user?.sub || '', body?.body || '');
  }

  @Post(':id/assign')
  assign(
    @Param('id') id: string,
    @Body() body: { userId?: string; role?: 'ADMIN' | 'BROKER' | 'CONSULTANT' | 'HUNTER' },
    @Req() req: Request & { user?: { sub?: string } },
  ) {
    return this.applications.assign(id, req.user?.sub || '', {
      userId: body?.userId,
      role: body?.role as any,
    });
  }

  @Post(':id/close')
  close(
    @Param('id') id: string,
    @Body() body: { reason?: string },
    @Req() req: Request & { user?: { sub?: string } },
  ) {
    return this.applications.close(id, req.user?.sub || '', body?.reason);
  }
}
