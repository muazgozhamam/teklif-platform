import { Body, Controller, Get, Param, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';
import { OffersService } from './offers.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateOfferDto } from './dto/create-offer.dto';
import { UpdateOfferDto } from './dto/update-offer.dto';

@Controller()
@UseGuards(JwtAuthGuard)
export class OffersController {
  constructor(private readonly offersService: OffersService) {}

  @Post('leads/:leadId/offers')
  async create(@Param('leadId') leadId: string, @Body() dto: CreateOfferDto, @Req() req: any) {
    return this.offersService.createOffer(leadId, req.user.id, dto);
  }

  @Patch('offers/:id')
  async update(@Param('id') id: string, @Body() dto: UpdateOfferDto, @Req() req: any) {
    return this.offersService.updateOffer(id, req.user.id, dto);
  }

  @Post('offers/:id/send')
  async send(@Param('id') id: string, @Req() req: any) {
    return this.offersService.sendOffer(id, req.user.id);
  }

  @Post('offers/:id/cancel')
  async cancel(@Param('id') id: string, @Req() req: any) {
    return this.offersService.cancelOffer(id, req.user.id);
  }

  @Get('offers')
  async myOffers(@Req() req: any, @Query('status') status?: string) {
    return this.offersService.myOffers(req.user.id, status);
  }
}
