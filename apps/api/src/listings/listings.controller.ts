import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Put,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ListingsService } from './listings.service';
import type {
  CreateListingDto,
  ListListingsQuery,
  UpdateListingDto,
  UpdateSahibindenDto,
  UpsertListingAttributesDto,
} from './listings.dto';

type ReqUser = Request & { user?: { sub?: string; role?: string } };

function resolveIp(req: Request) {
  const xfwd = req.headers['x-forwarded-for'];
  if (typeof xfwd === 'string' && xfwd.trim()) return xfwd.split(',')[0].trim();
  return req.ip || 'unknown';
}

@Controller('public/listings')
export class PublicListingsController {
  constructor(private readonly listings: ListingsService) {}

  @Get('categories')
  categories() {
    return this.listings.getPublicCategoriesTree();
  }

  @Get('categories/leaves')
  leaves() {
    return this.listings.getPublicCategoryLeaves();
  }

  @Get('categories/attributes')
  categoryAttributes(@Query('pathKey') pathKey: string) {
    return this.listings.getPublicCategoryAttributes(pathKey);
  }

  @Get()
  list(@Req() req: Request, @Query() query: ListListingsQuery) {
    return this.listings.listPublic(query, resolveIp(req));
  }

  @Get(':id')
  detail(@Param('id') id: string) {
    return this.listings.getPublicById(id);
  }
}

@UseGuards(JwtAuthGuard)
@Controller('listings')
export class ListingsController {
  constructor(private readonly listings: ListingsService) {}

  @Post()
  create(@Req() req: ReqUser, @Body() dto: CreateListingDto) {
    return this.listings.createForUser(
      { sub: String(req.user?.sub || ''), role: String(req.user?.role || '') },
      dto || {},
    );
  }

  @Get()
  list(@Req() req: ReqUser, @Query() query: ListListingsQuery) {
    return this.listings.listForUser(
      { sub: String(req.user?.sub || ''), role: String(req.user?.role || '') },
      query || {},
    );
  }

  // legacy compatibility
  @Get('/deals/:dealId/listing')
  async getByDealId(@Req() req: ReqUser, @Param('dealId') dealId: string) {
    const created = await this.listings.upsertFromDealMeta(dealId);
    return this.listings.getByIdForUser(
      { sub: String(req.user?.sub || ''), role: String(req.user?.role || '') },
      created.listing.id,
    );
  }

  @Post('/deals/:dealId/listing')
  upsertFromDeal(@Param('dealId') dealId: string) {
    return this.listings.upsertFromDealMeta(dealId);
  }

  @Get(':id')
  getById(@Req() req: ReqUser, @Param('id') id: string) {
    return this.listings.getByIdForUser(
      { sub: String(req.user?.sub || ''), role: String(req.user?.role || '') },
      id,
    );
  }

  @Patch(':id')
  patch(@Req() req: ReqUser, @Param('id') id: string, @Body() dto: UpdateListingDto) {
    return this.listings.patchForUser(
      { sub: String(req.user?.sub || ''), role: String(req.user?.role || '') },
      id,
      dto || {},
    );
  }

  @Put(':id/attributes')
  upsertAttributes(@Req() req: ReqUser, @Param('id') id: string, @Body() dto: UpsertListingAttributesDto) {
    return this.listings.upsertAttributesForUser(
      { sub: String(req.user?.sub || ''), role: String(req.user?.role || '') },
      id,
      dto || { attributes: [] },
    );
  }

  @Post(':id/publish')
  publish(@Req() req: ReqUser, @Param('id') id: string) {
    return this.listings.publishForUser(
      { sub: String(req.user?.sub || ''), role: String(req.user?.role || '') },
      id,
    );
  }

  @Post(':id/archive')
  archive(@Req() req: ReqUser, @Param('id') id: string) {
    return this.listings.archiveForUser(
      { sub: String(req.user?.sub || ''), role: String(req.user?.role || '') },
      id,
    );
  }

  @Get(':id/export/sahibinden')
  exportSahibinden(@Req() req: ReqUser, @Param('id') id: string) {
    return this.listings.getSahibindenExportForUser(
      { sub: String(req.user?.sub || ''), role: String(req.user?.role || '') },
      id,
    );
  }

  @Patch(':id/sahibinden')
  patchSahibinden(@Req() req: ReqUser, @Param('id') id: string, @Body() dto: UpdateSahibindenDto) {
    return this.listings.patchSahibindenForUser(
      { sub: String(req.user?.sub || ''), role: String(req.user?.role || '') },
      id,
      dto || {},
    );
  }
}
