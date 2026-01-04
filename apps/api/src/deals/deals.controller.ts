import { Controller, Get, Post, Param, Req, Query } from '@nestjs/common';
import { DealsService } from './deals.service';

@Controller('deals')
export class DealsController {
  constructor(private readonly deals: DealsService) {}

  
  // Consultant inbox endpoints
  // pending: unassigned OPEN deals
  @Get('inbox/pending')
  inboxPending(@Query('take') take?: string, @Query('skip') skip?: string) {
    const t = take ? Math.min(Math.max(parseInt(take, 10) || 0, 0), 50) : 20;
    const s = skip ? Math.max(parseInt(skip, 10) || 0, 0) : 0;
    return this.deals.listPendingInbox({ take: t, skip: s });
  }

  // mine: OPEN deals assigned to current consultant (x-user-id header)
  @Get('inbox/mine')
  inboxMine(@Req() req: any, @Query('take') take?: string, @Query('skip') skip?: string) {
    const userId = String(req.headers['x-user-id'] ?? '').trim();
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


  // Assign deal to current consultant (x-user-id)
  @Post(':id/assign-to-me')
  assignToMe(@Req() req: any, @Param('id') id: string) {
    const userId = String(req.headers['x-user-id'] ?? '').trim();
    return this.deals.assignToMe(id, userId);
  }

  @Post(':id/link-listing/:listingId')
  linkListing(@Req() req: any, @Param('id') id: string, @Param('listingId') listingId: string) {
    const userId = String(req.headers['x-user-id'] ?? '').trim();
    return this.deals.linkListing(id, listingId, userId);
  }

}
