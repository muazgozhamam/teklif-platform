import { Body, Controller, Get, Post, Param, Req, Query, UseGuards } from '@nestjs/common';
import { DealsService } from './deals.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../common/roles/roles.guard';
import { Roles } from '../common/roles/roles.decorator';
import { AuditService } from '../audit/audit.service';
import { AuditEntityType } from '@prisma/client';

@Controller('deals')
export class DealsController {
  constructor(private readonly deals: DealsService, private readonly audit: AuditService) {}

  
  // Consultant inbox endpoints
  // pending: unassigned OPEN deals
  @Get('inbox/pending')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('CONSULTANT', 'ADMIN')
  inboxPending(@Query('take') take?: string, @Query('skip') skip?: string) {
    const t = take ? Math.min(Math.max(parseInt(take, 10) || 0, 0), 50) : 20;
    const s = skip ? Math.max(parseInt(skip, 10) || 0, 0) : 0;
    return this.deals.listPendingInbox({ take: t, skip: s });
  }

  // mine: OPEN deals assigned to current consultant (x-user-id header)
  @Get('inbox/mine')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('CONSULTANT', 'ADMIN')
  inboxMine(@Req() req: any, @Query('take') take?: string, @Query('skip') skip?: string) {
    const userId = String(req.user?.sub ?? req.user?.id ?? req.headers['x-user-id'] ?? '').trim();
    const t = take ? Math.min(Math.max(parseInt(take, 10) || 0, 0), 50) : 20;
    const s = skip ? Math.max(parseInt(skip, 10) || 0, 0) : 0;
    return this.deals.listMineInbox(userId, { take: t, skip: s });
  }


  
  // DEV helper: list user ids (for local testing / seeding)
  @Get('dev/user-ids')
  devUserIds(@Query('take') take?: string) {
    const t = take ? Math.min(Math.max(parseInt(take, 10) || 0, 0), 50) : 20;
    return this.deals.devListUserIds(t);
  }

  @Post(':id/won')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('BROKER', 'ADMIN')
  markWon(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { closingPrice?: number | string; currency?: string },
  ) {
    const actor = {
      actorUserId: String(req.user?.sub ?? req.user?.id ?? '').trim() || null,
      actorRole: String(req.user?.role ?? '').trim().toUpperCase() || null,
    };
    return this.deals.markWon(id, { closingPrice: body?.closingPrice ?? 0, currency: body?.currency }, actor);
  }

  @Get(':id/commission-snapshot')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN', 'BROKER', 'CONSULTANT')
  getCommissionSnapshot(@Req() req: any, @Param('id') id: string) {
    const actor = {
      actorUserId: String(req.user?.sub ?? req.user?.id ?? '').trim() || null,
      actorRole: String(req.user?.role ?? '').trim().toUpperCase() || null,
    };
    return this.deals.getCommissionSnapshot(id, actor);
  }

  @Get(':id/audit')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN', 'BROKER', 'CONSULTANT')
  async auditTimeline(@Req() req: any, @Param('id') id: string) {
    const actor = {
      userId: String(req.user?.sub ?? req.user?.id ?? '').trim(),
      role: String(req.user?.role ?? '').trim().toUpperCase(),
    };
    await this.audit.assertCanReadDeal(actor, id);
    return this.audit.listByEntity(AuditEntityType.DEAL, id, 'asc');
  }

  @Get(':id')
  getById(@Param('id') id: string) {
    return this.deals.getById(id);
  }

  @Get('by-lead/:leadId')
  getByLead(@Param('leadId') leadId: string) {
    return this.deals.getByLeadId(leadId);
  }

  @Post(':id/match')
  match(@Param('id') id: string) {
    return this.deals.matchDeal(id);
  }

  @Post(':id/assign')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('BROKER', 'ADMIN')
  assignByBroker(@Req() req: any, @Param('id') id: string, @Body() body: { consultantId?: string }) {
    const consultantId = String(body?.consultantId ?? '').trim();
    const actor = {
      actorUserId: String(req.user?.sub ?? req.user?.id ?? '').trim() || null,
      actorRole: String(req.user?.role ?? '').trim().toUpperCase() || null,
    };
    return this.deals.assignByBroker(id, consultantId, actor);
  }


  // Assign deal to current consultant (x-user-id)
  @Post(':id/assign-to-me')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('CONSULTANT', 'ADMIN')
  assignToMe(@Req() req: any, @Param('id') id: string) {
    const userId = String(req.user?.sub ?? req.user?.id ?? req.headers['x-user-id'] ?? '').trim();
    return this.deals.assignToMe(id, userId);
  }

  @Post(':id/link-listing/:listingId')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('CONSULTANT', 'ADMIN')
  linkListing(@Req() req: any, @Param('id') id: string, @Param('listingId') listingId: string) {
    const userId = String(req.user?.sub ?? req.user?.id ?? req.headers['x-user-id'] ?? '').trim();
    return this.deals.linkListing(id, listingId, userId);
  }

}
