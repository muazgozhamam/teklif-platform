import { BadRequestException, Body, Controller, Get, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../auth/jwt-auth.guard';
import { Roles } from '../../common/roles/roles.decorator';
import { RolesGuard } from '../../common/roles/roles.guard';
import { OrgService } from '../../org/org.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
@Controller('admin/org')
export class AdminOrgController {
  constructor(private readonly org: OrgService) {}

  @Post('regions')
  createRegion(@Req() req: any, @Body() body: { city?: string; district?: string }) {
    return this.org.createRegion(String(body.city ?? ''), body.district, this.actor(req));
  }

  @Get('regions')
  listRegions(@Query('city') city?: string) {
    return this.org.listRegions(city);
  }

  @Post('offices')
  createOffice(
    @Req() req: any,
    @Body() body: { name?: string; regionId?: string; brokerId?: string | null; overridePercent?: number | null },
  ) {
    const name = String(body.name ?? '');
    const regionId = String(body.regionId ?? '');
    const overridePercent = body.overridePercent === undefined || body.overridePercent === null
      ? null
      : Number(body.overridePercent);
    if (overridePercent !== null && Number.isNaN(overridePercent)) {
      throw new BadRequestException('overridePercent must be a number');
    }
    return this.org.createOffice(name, regionId, body.brokerId ?? null, overridePercent, this.actor(req));
  }

  @Get('offices')
  listOffices(@Query('regionId') regionId?: string) {
    return this.org.listOffices(regionId);
  }

  @Get('offices/:officeId/users')
  listOfficeUsers(@Param('officeId') officeId: string) {
    return this.org.listOfficeUsers(officeId);
  }

  @Get('regions/:regionId/offices')
  listRegionOffices(@Param('regionId') regionId: string) {
    return this.org.listRegionOffices(regionId);
  }

  @Post('offices/:officeId/broker')
  assignOfficeBroker(
    @Param('officeId') officeId: string,
    @Body() body: { brokerId?: string | null },
  ) {
    return this.org.assignOfficeBroker(officeId, body.brokerId ?? null);
  }

  @Post('offices/:officeId/override-policy')
  setOfficeOverridePolicy(
    @Param('officeId') officeId: string,
    @Body() body: { overridePercent?: number | null },
  ) {
    const overridePercent = body.overridePercent === undefined || body.overridePercent === null
      ? null
      : Number(body.overridePercent);
    if (overridePercent !== null && Number.isNaN(overridePercent)) {
      throw new BadRequestException('overridePercent must be a number');
    }
    return this.org.setOfficeOverridePolicy(officeId, overridePercent);
  }

  @Get('franchise/summary')
  franchiseSummary() {
    return this.org.getFranchiseSummary();
  }

  @Post('users/office')
  assignUserOffice(
    @Req() req: any,
    @Body() body: { userId?: string; officeId?: string | null },
  ) {
    return this.org.assignUserOffice(String(body.userId ?? ''), body.officeId ?? null, this.actor(req));
  }

  @Post('leads/region')
  assignLeadRegion(
    @Req() req: any,
    @Body() body: { leadId?: string; regionId?: string | null },
  ) {
    return this.org.assignLeadRegion(String(body.leadId ?? ''), body.regionId ?? null, this.actor(req));
  }

  private actor(req: { user?: { sub?: string; id?: string; role?: string } }) {
    return {
      actorUserId: String(req?.user?.sub ?? req?.user?.id ?? '').trim() || null,
      actorRole: String(req?.user?.role ?? '').trim().toUpperCase() || null,
    };
  }
}
