#!/usr/bin/env bash
set -euo pipefail

# MUST RUN FROM repo root
if [ ! -d "apps/api" ]; then
  echo "HATA: Repo kökünde değilsin. Beklenen: teklif-platform/apps/api"
  exit 1
fi

API_DIR="apps/api"

mkfile_force () {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat > "$path"
  echo "WROTE: $path"
}

echo "==> Recreating offers files (safe heredoc, no bash expansion)..."

mkfile_force "$API_DIR/src/offers/offers.service.ts" <<'EOF'
import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class OffersService {
  constructor(private readonly prisma: PrismaService) {}

  private async assertLeadAssignedTo(leadId: string, userId: string) {
    const lead = await this.prisma.lead.findUnique({ where: { id: leadId } });
    if (!lead) throw new NotFoundException('Lead not found');
    if (!lead.assignedTo) throw new BadRequestException('Lead is not assigned');
    if (lead.assignedTo !== userId) throw new ForbiddenException('You are not assigned to this lead');
    return lead;
  }

  async createOffer(
    leadId: string,
    meId: string,
    dto: { amount: number; currency?: string; description?: string },
  ) {
    await this.assertLeadAssignedTo(leadId, meId);

    const offer = await this.prisma.offer.create({
      data: {
        leadId,
        consultantId: meId,
        amount: dto.amount,
        currency: dto.currency ?? 'TRY',
        description: dto.description,
        status: 'DRAFT',
      },
    });

    return { ok: true, offer };
  }

  async updateOffer(
    offerId: string,
    meId: string,
    dto: { amount?: number; currency?: string; description?: string },
  ) {
    const offer = await this.prisma.offer.findUnique({ where: { id: offerId } });
    if (!offer) throw new NotFoundException('Offer not found');
    if (offer.consultantId !== meId) throw new ForbiddenException('Not your offer');
    if (offer.status !== 'DRAFT') throw new BadRequestException('Only DRAFT offers can be updated');

    const updated = await this.prisma.offer.update({
      where: { id: offerId },
      data: {
        amount: dto.amount ?? undefined,
        currency: dto.currency ?? undefined,
        description: dto.description ?? undefined,
      },
    });

    return { ok: true, offer: updated };
  }

  async sendOffer(offerId: string, meId: string) {
    const offer = await this.prisma.offer.findUnique({ where: { id: offerId } });
    if (!offer) throw new NotFoundException('Offer not found');
    if (offer.consultantId !== meId) throw new ForbiddenException('Not your offer');
    if (offer.status !== 'DRAFT') throw new BadRequestException('Only DRAFT offers can be sent');

    const updated = await this.prisma.$transaction(async (tx) => {
      const sent = await tx.offer.update({
        where: { id: offerId },
        data: { status: 'SENT', sentAt: new Date() },
      });

      await tx.lead.update({
        where: { id: offer.leadId },
        data: { status: 'OFFERED' },
      });

      return sent;
    });

    return { ok: true, offer: updated };
  }

  async cancelOffer(offerId: string, meId: string) {
    const offer = await this.prisma.offer.findUnique({ where: { id: offerId } });
    if (!offer) throw new NotFoundException('Offer not found');
    if (offer.consultantId !== meId) throw new ForbiddenException('Not your offer');
    if (offer.status === 'ACCEPTED' || offer.status === 'REJECTED') {
      throw new BadRequestException('Decided offers cannot be cancelled');
    }

    const updated = await this.prisma.offer.update({
      where: { id: offerId },
      data: { status: 'CANCELLED' },
    });

    return { ok: true, offer: updated };
  }

  // ADMIN karar
  async acceptOfferAdmin(offerId: string) {
    const offer = await this.prisma.offer.findUnique({ where: { id: offerId } });
    if (!offer) throw new NotFoundException('Offer not found');
    if (offer.status !== 'SENT') throw new BadRequestException('Only SENT offers can be accepted');

    const updated = await this.prisma.$transaction(async (tx) => {
      const accepted = await tx.offer.update({
        where: { id: offerId },
        data: { status: 'ACCEPTED', decidedAt: new Date() },
      });

      await tx.offer.updateMany({
        where: {
          leadId: offer.leadId,
          id: { not: offerId },
          status: { in: ['DRAFT', 'SENT'] },
        },
        data: { status: 'CANCELLED' },
      });

      await tx.lead.update({
        where: { id: offer.leadId },
        data: { status: 'WON' },
      });

      return accepted;
    });

    return { ok: true, offer: updated };
  }

  async rejectOfferAdmin(offerId: string) {
    const offer = await this.prisma.offer.findUnique({ where: { id: offerId } });
    if (!offer) throw new NotFoundException('Offer not found');
    if (offer.status !== 'SENT') throw new BadRequestException('Only SENT offers can be rejected');

    const updated = await this.prisma.offer.update({
      where: { id: offerId },
      data: { status: 'REJECTED', decidedAt: new Date() },
    });

    return { ok: true, offer: updated };
  }

  async myOffers(meId: string, status?: string) {
    const items = await this.prisma.offer.findMany({
      where: {
        consultantId: meId,
        ...(status ? { status: status as any } : {}),
      },
      orderBy: { createdAt: 'desc' },
    });

    return { ok: true, items };
  }
}
EOF

mkfile_force "$API_DIR/src/offers/offers.controller.ts" <<'EOF'
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
EOF

mkfile_force "$API_DIR/src/offers/admin-offers.controller.ts" <<'EOF'
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
EOF

mkfile_force "$API_DIR/src/offers/offers.module.ts" <<'EOF'
import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { OffersService } from './offers.service';
import { OffersController } from './offers.controller';
import { AdminOffersController } from './admin-offers.controller';

@Module({
  imports: [PrismaModule],
  controllers: [OffersController, AdminOffersController],
  providers: [OffersService],
})
export class OffersModule {}
EOF

echo "==> Running prisma migrate + generate..."
cd "$API_DIR"
pnpm prisma migrate dev --name offer_system
pnpm prisma generate
cd - >/dev/null

echo
echo "==> Determine how to run API dev script..."

node - <<'NODE'
const fs = require('fs');

function readJson(p){ return JSON.parse(fs.readFileSync(p,'utf8')); }

const apiPkgPath = 'apps/api/package.json';
const rootPkgPath = 'package.json';

const apiPkg = fs.existsSync(apiPkgPath) ? readJson(apiPkgPath) : null;
const rootPkg = fs.existsSync(rootPkgPath) ? readJson(rootPkgPath) : null;

console.log('apps/api scripts:', apiPkg?.scripts || {});
console.log('root scripts:', rootPkg?.scripts || {});

function pickCmd(scripts){
  if (!scripts) return null;
  if (scripts.dev) return 'dev';
  if (scripts['start:dev']) return 'start:dev';
  if (scripts['start:debug']) return 'start:debug';
  return null;
}

const apiCmd = pickCmd(apiPkg?.scripts);
const rootCmd = pickCmd(rootPkg?.scripts);

console.log('\n==> RECOMMENDED RUN COMMANDS:');
if (apiCmd) {
  console.log(`1) cd apps/api && pnpm run ${apiCmd}`);
} else if (rootCmd) {
  console.log(`1) pnpm run ${rootCmd}`);
  console.log(`   (if monorepo filter needed, try: pnpm -F api run ${rootCmd}  OR  pnpm --filter api run ${rootCmd})`);
} else {
  console.log("1) No dev script found. Open package.json and check scripts.");
}
NODE

echo
echo "==> DONE"
