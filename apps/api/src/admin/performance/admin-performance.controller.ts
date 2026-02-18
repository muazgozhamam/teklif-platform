import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../auth/jwt-auth.guard';
import { Roles } from '../../common/roles/roles.decorator';
import { RolesGuard } from '../../common/roles/roles.guard';
import { AdminPerformanceService } from './admin-performance.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
@Controller('admin/performance')
export class AdminPerformanceController {
  constructor(private readonly service: AdminPerformanceService) {}

  @Get('overview')
  getOverview(@Query('from') from?: string, @Query('to') to?: string) {
    return this.service.getOverview(from, to);
  }

  @Get('funnel/ref-to-portfolio')
  getRefToPortfolio(@Query('from') from?: string, @Query('to') to?: string) {
    return this.service.getFunnelRefToPortfolio(from, to);
  }

  @Get('funnel/portfolio-to-sale')
  getPortfolioToSale(@Query('from') from?: string, @Query('to') to?: string) {
    return this.service.getFunnelPortfolioToSale(from, to);
  }

  @Get('leaderboard/consultants')
  getConsultants(@Query('from') from?: string, @Query('to') to?: string) {
    return this.service.getLeaderboardConsultants(from, to);
  }

  @Get('leaderboard/partners')
  getPartners(@Query('from') from?: string, @Query('to') to?: string) {
    return this.service.getLeaderboardPartners(from, to);
  }

  @Get('finance/revenue')
  getRevenue(@Query('from') from?: string, @Query('to') to?: string) {
    return this.service.getFinanceRevenue(from, to);
  }

  @Get('finance/commission')
  getCommission(@Query('from') from?: string, @Query('to') to?: string) {
    return this.service.getFinanceCommission(from, to);
  }

  @Get('consultants/:id')
  getConsultantDetail(@Param('id') id: string, @Query('from') from?: string, @Query('to') to?: string) {
    return this.service.getConsultantDetail(id, from, to);
  }

  @Get('partners/:id')
  getPartnerDetail(@Param('id') id: string, @Query('from') from?: string, @Query('to') to?: string) {
    return this.service.getPartnerDetail(id, from, to);
  }
}
