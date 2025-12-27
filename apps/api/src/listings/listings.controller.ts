import { Controller, Get, Post, Param, Put, Body, Query, Req, UseGuards } from '@nestjs/common';
import { ListingsService } from './listings.service';
import { ConsultantGuard } from './consultant.guard';
import * as ListingDto from './listings.dto';
import { ListingStatus } from '@prisma/client';

@Controller('listings')
export class ListingsController {
  constructor(private readonly listings: ListingsService) {}

  @Get(':id')
  getById(@Param('id') id: string) {
    return this.listings.getById(id);
  }

  @Get()
  list(@Query('consultantId') consultantId?: string, @Query('status') status?: ListingStatus) {
    return this.listings.list({ consultantId, status });
  }

  @UseGuards(ConsultantGuard)
  @Post()
  create(@Req() req: any, @Body() dto: ListingDto.CreateListingDto) {
    const userId = String(req.headers['x-user-id']);
    return this.listings.create(userId, dto);
  }

  @UseGuards(ConsultantGuard)
  @Put(':id')
  update(@Req() req: any, @Param('id') id: string, @Body() dto: ListingDto.UpdateListingDto) {
    const userId = String(req.headers['x-user-id']);
    return this.listings.update(id, userId, dto);
  }

  @Get('/deals/:dealId/listing')
  getByDeal(@Param('dealId') dealId: string) {
    return this.listings.getByDealId(dealId);
  }

  @Post('/deals/:dealId/listing')
  upsertFromDeal(@Param('dealId') dealId: string) {
    return this.listings.upsertFromDeal(dealId);
  }

}
