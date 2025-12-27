import { Controller, Param, Post, UseGuards } from '@nestjs/common';
import { OffersService } from './offers.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../common/roles/roles.decorator';
import { RolesGuard } from '../common/roles/roles.guard';

@Controller('admin/offers')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AdminOffersController {
  constructor(private readonly offersService: OffersService) {}

  @Post(':id/accept')
  @Roles('ADMIN')
  async accept(@Param('id') id: string) {
    return this.offersService.acceptOfferAdmin(id);
  }

  @Post(':id/reject')
  @Roles('ADMIN')
  async reject(@Param('id') id: string) {
    return this.offersService.rejectOfferAdmin(id);
  }
}
