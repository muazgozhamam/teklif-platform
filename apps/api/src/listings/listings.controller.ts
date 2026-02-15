import { Controller, Get, Post, Put, Param, Body, Res, Query, UseGuards, Req} from '@nestjs/common';
import type { Response } from 'express';
import { ListingsService } from './listings.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../common/roles/roles.guard';
import { Roles } from '../common/roles/roles.decorator';
import { AuditService } from '../audit/audit.service';
import { AuditEntityType } from '@prisma/client';

@Controller('listings')
export class ListingsController {
  constructor(private readonly listings: ListingsService, private readonly audit: AuditService) {}

  @Get(':id')
  async getOne(@Param('id') id: string) {
    return this.listings.getById(id);
  }

  @Get(':id/audit')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN', 'BROKER', 'CONSULTANT')
  async getAudit(@Req() req: any, @Param('id') id: string) {
    const actor = {
      userId: String(req.user?.sub ?? req.user?.id ?? '').trim(),
      role: String(req.user?.role ?? '').trim().toUpperCase(),
    };
    await this.audit.assertCanReadListing(actor, id);
    return this.audit.listByEntity(AuditEntityType.LISTING, id, 'asc');
  }

  
  @Get()
  async   list(@Query() query: any) {
    return this.listings.list(query as any);
  }


  @Post()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('CONSULTANT', 'ADMIN')
  async create(@Body() dto: any) {
    return this.listings.create(dto);
  }

  @Put(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('CONSULTANT', 'ADMIN')
  async update(@Param('id') id: string, @Body() dto: any) {
    return this.listings.update(id, dto);
  }

  @Get('/deals/:dealId/listing')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('CONSULTANT', 'ADMIN')
  async getByDealId(@Param('dealId') dealId: string) {
    return this.listings.getByDealId(dealId);
  }

  @Post('/deals/:dealId/listing')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('CONSULTANT', 'ADMIN')
  async upsertFromDeal(@Req() req: any, @Param('dealId') dealId: string, @Res({ passthrough: true }) res: Response) {
    const actor = {
      actorUserId: String(req.user?.sub ?? req.user?.id ?? '').trim() || null,
      actorRole: String(req.user?.role ?? '').trim().toUpperCase() || null,
    };
    const r = await this.listings.upsertFromDealMeta(dealId, actor);
    res.status(r.created ? 201 : 200);
    return r.listing;
  }
  @Post(':id/publish')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('CONSULTANT', 'ADMIN')
  async publish(@Req() req: any, @Param('id') id: string) {
    const actor = {
      actorUserId: String(req.user?.sub ?? req.user?.id ?? '').trim() || null,
      actorRole: String(req.user?.role ?? '').trim().toUpperCase() || null,
    };
    return this.listings.publish(id, actor);
  }

  @Post(':id/sold')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('CONSULTANT', 'ADMIN')
  async sold(@Req() req: any, @Param('id') id: string) {
    const actor = {
      actorUserId: String(req.user?.sub ?? req.user?.id ?? '').trim() || null,
      actorRole: String(req.user?.role ?? '').trim().toUpperCase() || null,
    };
    return this.listings.markSold(id, actor);
  }

}
