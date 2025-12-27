import { Controller, Get, Post, Put, Param, Body, Res, Query} from '@nestjs/common';
import type { Response } from 'express';
import { ListingsService } from './listings.service';

@Controller('listings')
export class ListingsController {
  constructor(private readonly listings: ListingsService) {}

  @Get(':id')
  async getOne(@Param('id') id: string) {
    return this.listings.getById(id);
  }

  
  @Get()
  async   list(@Query() query: any) {
    return this.listings.list(query as any);
  }


  @Post()
  async create(@Body() dto: any) {
    return this.listings.create(dto);
  }

  @Put(':id')
  async update(@Param('id') id: string, @Body() dto: any) {
    return this.listings.update(id, dto);
  }

  @Get('/deals/:dealId/listing')
  async getByDealId(@Param('dealId') dealId: string) {
    return this.listings.getByDealId(dealId);
  }

  @Post('/deals/:dealId/listing')
  async upsertFromDeal(@Param('dealId') dealId: string, @Res({ passthrough: true }) res: Response) {
    const r = await this.listings.upsertFromDealMeta(dealId);
    res.status(r.created ? 201 : 200);
    return r.listing;
  }
  @Post(':id/publish')
  async publish(@Param('id') id: string) {
    return this.listings.publish(id);
  }

}
