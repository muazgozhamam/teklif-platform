import { Controller, Get, Post, Param, Req } from '@nestjs/common';
import { DealsService } from './deals.service';

@Controller('deals')
export class DealsController {
  constructor(private readonly deals: DealsService) {}

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

  @Post(':id/link-listing/:listingId')
  linkListing(@Req() req: any, @Param('id') id: string, @Param('listingId') listingId: string) {
    const userId = String(req.headers['x-user-id'] ?? '').trim();
    return this.deals.linkListing(id, listingId, userId);
  }

}
