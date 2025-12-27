import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
import { AdminLeadsService } from './admin-leads.service';
import { AssignLeadDto } from './dto/assign-lead.dto';
import { JwtAuthGuard } from '../../auth/jwt-auth.guard';
import { Roles } from '../../common/roles/roles.decorator';
import { RolesGuard } from '../../common/roles/roles.guard';

@Controller('admin/leads')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AdminLeadsController {
  constructor(private readonly adminLeadsService: AdminLeadsService) {}

  @Post(':id/assign')
  @Roles('ADMIN')
  async assignLead(@Param('id') leadId: string, @Body() dto: AssignLeadDto) {
    return this.adminLeadsService.assignLead(leadId, dto.userId);
  }
}
