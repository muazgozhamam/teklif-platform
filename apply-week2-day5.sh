#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API="$ROOT/apps/api"

if [ ! -d "$API" ]; then
  echo "apps/api not found. Run this from teklif-platform root."
  exit 1
fi

echo "==> Ensuring common lead enums exist..."
mkdir -p "$API/src/common"

cat > "$API/src/common/lead.enums.ts" <<'TS'
export enum LeadStatus {
  DRAFT = 'DRAFT',
  PENDING_BROKER_APPROVAL = 'PENDING_BROKER_APPROVAL',
  ACTIVE = 'ACTIVE',
  REJECTED = 'REJECTED',
}
TS

echo "==> Normalizing LeadsController routes (broker queue + approve/reject)..."
# If you already have these files, this will overwrite with the normalized version.
mkdir -p "$API/src/leads"

cat > "$API/src/leads/leads.controller.ts" <<'TS'
import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { RolesGuard } from '../common/roles.guard';
import { Roles } from '../common/roles.decorator';
import { Role } from '../common/role.enum';
import { LeadsService } from './leads.service';

@Controller()
export class LeadsController {
  constructor(private leads: LeadsService) {}

  // Hunter/Agent: create lead
  @UseGuards(JwtAuthGuard)
  @Post('leads')
  create(@Req() req: any, @Body() body: any) {
    return this.leads.createLead(req.user.id, body);
  }

  // Hunter/Agent: list my leads
  @UseGuards(JwtAuthGuard)
  @Get('leads/me')
  myLeads(@Req() req: any) {
    return this.leads.listMyLeads(req.user.id);
  }

  // Broker/Admin: pending queue
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.BROKER, Role.ADMIN)
  @Get('broker/leads/pending')
  pending() {
    return this.leads.listPendingForBroker();
  }

  // Broker/Admin: approve
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.BROKER, Role.ADMIN)
  @Post('broker/leads/:id/approve')
  approve(@Req() req: any, @Param('id') id: string, @Body() body: any) {
    return this.leads.approveLead(id, req.user.id, body?.brokerNote);
  }

  // Broker/Admin: reject
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.BROKER, Role.ADMIN)
  @Post('broker/leads/:id/reject')
  reject(@Req() req: any, @Param('id') id: string, @Body() body: any) {
    return this.leads.rejectLead(id, req.user.id, body?.brokerNote);
  }
}
TS

echo "==> Ensuring LeadsModule exports controller..."
cat > "$API/src/leads/leads.module.ts" <<'TS'
import { Module } from '@nestjs/common';
import { LeadsService } from './leads.service';
import { LeadsController } from './leads.controller';

@Module({
  providers: [LeadsService],
  controllers: [LeadsController],
  exports: [LeadsService],
})
export class LeadsModule {}
TS

echo "==> Hardening DealsController role access (already broker/admin, re-writing safely)..."
mkdir -p "$API/src/deals"

cat > "$API/src/deals/deals.controller.ts" <<'TS'
import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { RolesGuard } from '../common/roles.guard';
import { Roles } from '../common/roles.decorator';
import { Role } from '../common/role.enum';
import { DealsService } from './deals.service';
import { CreateDealDto } from './dto/create-deal.dto';

@Controller('broker/deals')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.BROKER, Role.ADMIN)
export class DealsController {
  constructor(private deals: DealsService) {}

  @Post()
  create(@Req() req: any, @Body() dto: CreateDealDto) {
    return this.deals.createDeal({
      leadId: dto.leadId,
      salePrice: dto.salePrice,
      commissionRate: dto.commissionRate,
      createdById: req.user.id,
    });
  }

  @Get()
  list() {
    return this.deals.listDeals();
  }

  @Get(':id/ledger')
  ledger(@Param('id') id: string) {
    return this.deals.getLedger(id);
  }
}
TS

echo "==> Done."
echo "Next:"
echo "  cd apps/api && pnpm dev"
echo ""
echo "E2E Test (copy/paste):"
echo "  1) Admin login token:"
echo "     TOKEN=\$(curl -s -X POST http://localhost:3001/auth/login -H 'Content-Type: application/json' -d '{\"email\":\"admin@teklif.local\",\"password\":\"Admin123!\"}' | node -p \"JSON.parse(require('fs').readFileSync(0,'utf8')).accessToken\")"
echo ""
echo "  2) Create a lead (as admin for quick test):"
echo "     LEAD=\$(curl -s -X POST http://localhost:3001/leads -H 'Content-Type: application/json' -H \"Authorization: Bearer \$TOKEN\" -d '{\"category\":\"KONUT\",\"title\":\"Konya test 2+1\",\"city\":\"Konya\",\"district\":\"Meram\",\"neighborhood\":\"Aksinne\",\"price\":5000000,\"areaM2\":95,\"notes\":\"Day5 test\"}' | node -p \"JSON.parse(require('fs').readFileSync(0,'utf8')).id\")"
echo ""
echo "  3) Broker pending queue:"
echo "     curl -s http://localhost:3001/broker/leads/pending -H \"Authorization: Bearer \$TOKEN\" && echo"
echo ""
echo "  4) Approve lead:"
echo "     curl -s -X POST http://localhost:3001/broker/leads/\$LEAD/approve -H 'Content-Type: application/json' -H \"Authorization: Bearer \$TOKEN\" -d '{\"brokerNote\":\"OK\"}' && echo"
echo ""
echo "  5) Create deal:"
echo "     DEAL=\$(curl -s -X POST http://localhost:3001/broker/deals -H 'Content-Type: application/json' -H \"Authorization: Bearer \$TOKEN\" -d \"{\\\"leadId\\\":\\\"\$LEAD\\\",\\\"salePrice\\\":5000000,\\\"commissionRate\\\":0.04}\" | node -p \"JSON.parse(require('fs').readFileSync(0,'utf8')).id\")"
echo ""
echo "  6) Fetch ledger:"
echo "     curl -s http://localhost:3001/broker/deals/\$DEAL/ledger -H \"Authorization: Bearer \$TOKEN\" && echo"
