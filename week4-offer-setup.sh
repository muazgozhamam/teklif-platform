#!/usr/bin/env bash
set -euo pipefail

# MUST RUN FROM REPO ROOT (teklif-platform)
ROOT="$(pwd)"
if [ ! -d "apps/api" ]; then
  echo "HATA: Bu script repo kökünde çalışmalı (teklif-platform)."
  echo "Beklenen yapı: teklif-platform/apps/api ..."
  exit 1
fi

API_DIR="apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"

if [ ! -f "$SCHEMA" ]; then
  echo "HATA: schema.prisma bulunamadı: $SCHEMA"
  exit 1
fi

echo "==> ROOT: $ROOT"
echo "==> Using schema: $SCHEMA"

backup="$SCHEMA.bak.$(date +%Y%m%d_%H%M%S)"
cp "$SCHEMA" "$backup"
echo "==> Backup created: $backup"

python3 - <<'PY'
import re, pathlib, sys

schema_path = pathlib.Path("apps/api/prisma/schema.prisma")
txt = schema_path.read_text(encoding="utf-8")

def has_block(pattern: str) -> bool:
    return re.search(pattern, txt, flags=re.M) is not None

def ensure_enum(enum_name: str, values: list[str]) -> str:
    global txt
    m = re.search(rf"(^enum\s+{re.escape(enum_name)}\s*\{{.*?^\}})\s*$", txt, flags=re.M|re.S)
    if not m:
        # add near top after datasource/generator blocks if possible
        insert_at = 0
        # try to insert after last generator/datasource block
        blocks = list(re.finditer(r"^(generator|datasource)\s+\w+\s*\{.*?^\}\s*$", txt, flags=re.M|re.S))
        if blocks:
            insert_at = blocks[-1].end()
        enum_body = "enum " + enum_name + " {\n" + "\n".join(f"  {v}" for v in values) + "\n}\n\n"
        txt = txt[:insert_at] + ("\n\n" if insert_at else "") + enum_body + txt[insert_at:]
        return "CREATED"
    block = m.group(1)
    existing = set(re.findall(r"^\s*([A-Z0-9_]+)\s*$", block, flags=re.M))
    missing = [v for v in values if v not in existing]
    if not missing:
        return "OK"
    # insert missing before closing }
    new_block = re.sub(r"^\}\s*$", "\n" + "\n".join(f"  {v}" for v in missing) + "\n}", block, flags=re.M)
    txt = txt[:m.start(1)] + new_block + txt[m.end(1):]
    return "UPDATED"

def ensure_model_offer() -> str:
    global txt
    if re.search(r"^model\s+Offer\s*\{", txt, flags=re.M):
        return "EXISTS"
    offer_model = """
model Offer {
  id            String      @id @default(cuid())
  createdAt     DateTime    @default(now())
  updatedAt     DateTime    @updatedAt

  leadId        String
  lead          Lead        @relation(fields: [leadId], references: [id], onDelete: Cascade)

  consultantId  String
  consultant    User        @relation(fields: [consultantId], references: [id], onDelete: Restrict)

  amount        Int
  currency      String      @default("TRY")
  description   String?

  status        OfferStatus @default(DRAFT)

  sentAt        DateTime?
  decidedAt     DateTime?

  @@index([leadId, status])
  @@index([consultantId, status])
}
"""
    # append at end
    txt = txt.rstrip() + "\n\n" + offer_model.strip() + "\n"
    return "CREATED"

def ensure_lead_offers_relation() -> str:
    global txt
    m = re.search(r"(^model\s+Lead\s*\{.*?^\})\s*$", txt, flags=re.M|re.S)
    if not m:
        return "LEAD_MODEL_NOT_FOUND"
    block = m.group(1)
    if re.search(r"^\s*offers\s+Offer\[\]\s*$", block, flags=re.M):
        return "OK"
    # add near answers if exists, else before closing
    lines = block.splitlines()
    # find a good insertion point: after answers LeadAnswer[] if present
    insert_idx = None
    for i, ln in enumerate(lines):
        if re.search(r"^\s*answers\s+LeadAnswer\[\]\s*$", ln):
            insert_idx = i + 1
            break
    if insert_idx is None:
        # before last "}"
        insert_idx = len(lines) - 1
    lines.insert(insert_idx, "  offers      Offer[]")
    new_block = "\n".join(lines)
    txt = txt[:m.start(1)] + new_block + txt[m.end(1):]
    return "UPDATED"

# Ensure enums / model / relation
print("==> Prisma updates:")
print("LeadStatus:", ensure_enum("LeadStatus", ["OPEN","ASSIGNED","OFFERED","WON","LOST","ARCHIVED"]))
print("OfferStatus:", ensure_enum("OfferStatus", ["DRAFT","SENT","ACCEPTED","REJECTED","CANCELLED"]))
print("Offer model:", ensure_model_offer())
print("Lead.offers relation:", ensure_lead_offers_relation())

schema_path.write_text(txt, encoding="utf-8")
PY

echo "==> Prisma schema updated."

# ---------------------------
# Create Nest files (do not overwrite if exist)
# ---------------------------
mkfile () {
  local path="$1"
  local content="$2"
  if [ -f "$path" ]; then
    echo "SKIP (exists): $path"
  else
    mkdir -p "$(dirname "$path")"
    cat > "$path" <<EOF
$content
EOF
    echo "CREATED: $path"
  fi
}

# Admin lead assign DTO/service/controller/module
mkfile "$API_DIR/src/admin/leads/dto/assign-lead.dto.ts" \
"import { IsString } from 'class-validator';

export class AssignLeadDto {
  @IsString()
  userId: string;
}
"

mkfile "$API_DIR/src/admin/leads/admin-leads.service.ts" \
"import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AdminLeadsService {
  constructor(private readonly prisma: PrismaService) {}

  async assignLead(leadId: string, userId: string) {
    const lead = await this.prisma.lead.findUnique({ where: { id: leadId } });
    if (!lead) throw new NotFoundException('Lead not found');

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    const updated = await this.prisma.lead.update({
      where: { id: leadId },
      data: {
        assignedTo: userId,
        status: 'ASSIGNED',
      },
    });

    return { ok: true, lead: updated };
  }
}
"

mkfile "$API_DIR/src/admin/leads/admin-leads.controller.ts" \
"import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
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
"

mkfile "$API_DIR/src/admin/leads/admin-leads.module.ts" \
"import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { AdminLeadsController } from './admin-leads.controller';
import { AdminLeadsService } from './admin-leads.service';

@Module({
  imports: [PrismaModule],
  controllers: [AdminLeadsController],
  providers: [AdminLeadsService],
})
export class AdminLeadsModule {}
"

# Offers module
mkfile "$API_DIR/src/offers/dto/create-offer.dto.ts" \
"import { IsInt, IsOptional, IsString, Min } from 'class-validator';

export class CreateOfferDto {
  @IsInt()
  @Min(1)
  amount: number;

  @IsOptional()
  @IsString()
  currency?: string;

  @IsOptional()
  @IsString()
  description?: string;
}
"

mkfile "$API_DIR/src/offers/dto/update-offer.dto.ts" \
"import { IsInt, IsOptional, IsString, Min } from 'class-validator';

export class UpdateOfferDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  amount?: number;

  @IsOptional()
  @IsString()
  currency?: string;

  @IsOptional()
  @IsString()
  description?: string;
}
"

mkfile "$API_DIR/src/offers/offers.service.ts" \
"import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
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

  async createOffer(leadId: string, meId: string, dto: { amount: number; currency?: string; description?: string }) {
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

  async updateOffer(offerId: string, meId: string, dto: { amount?: number; currency?: string; description?: string }) {
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
"

mkfile "$API_DIR/src/offers/offers.controller.ts" \
"import { Body, Controller, Get, Param, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';
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
"

mkfile "$API_DIR/src/offers/admin-offers.controller.ts" \
"import { Controller, Param, Post, UseGuards } from '@nestjs/common';
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
"

mkfile "$API_DIR/src/offers/offers.module.ts" \
"import { Module } from '@nestjs/common';
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
"

# ---------------------------
# Patch AppModule (best-effort)
# ---------------------------
APP_MODULE="$API_DIR/src/app.module.ts"
if [ -f "$APP_MODULE" ]; then
  python3 - <<'PY'
import re, pathlib
p = pathlib.Path("apps/api/src/app.module.ts")
txt = p.read_text(encoding="utf-8")

# add import if missing
if "OffersModule" not in txt:
    # insert after last import
    m = list(re.finditer(r"^import .*?;\s*$", txt, flags=re.M))
    if m:
        idx = m[-1].end()
        txt = txt[:idx] + "\nimport { OffersModule } from './offers/offers.module';" + txt[idx:]
    else:
        txt = "import { OffersModule } from './offers/offers.module';\n" + txt

# add to imports array
if re.search(r"imports\s*:\s*\[", txt) and "OffersModule" not in re.search(r"imports\s*:\s*\[(.*?)\]", txt, flags=re.S).group(1):
    txt = re.sub(r"(imports\s*:\s*\[)", r"\1\n    OffersModule,", txt, count=1)

p.write_text(txt, encoding="utf-8")
print("==> Patched AppModule with OffersModule (best-effort).")
PY
else
  echo "UYARI: $APP_MODULE bulunamadı. OffersModule import'unu elle eklemen gerekebilir."
fi

# ---------------------------
# Patch AdminModule (best-effort) if exists
# ---------------------------
ADMIN_MODULE="$API_DIR/src/admin/admin.module.ts"
if [ -f "$ADMIN_MODULE" ]; then
  python3 - <<'PY'
import re, pathlib
p = pathlib.Path("apps/api/src/admin/admin.module.ts")
txt = p.read_text(encoding="utf-8")

if "AdminLeadsModule" not in txt:
    m = list(re.finditer(r"^import .*?;\s*$", txt, flags=re.M))
    if m:
        idx = m[-1].end()
        txt = txt[:idx] + "\nimport { AdminLeadsModule } from './leads/admin-leads.module';" + txt[idx:]
    else:
        txt = "import { AdminLeadsModule } from './leads/admin-leads.module';\n" + txt

# add to imports array if present
m = re.search(r"imports\s*:\s*\[(.*?)\]", txt, flags=re.S)
if m and "AdminLeadsModule" not in m.group(1):
    txt = re.sub(r"(imports\s*:\s*\[)", r"\1\n    AdminLeadsModule,", txt, count=1)

p.write_text(txt, encoding="utf-8")
print("==> Patched AdminModule with AdminLeadsModule (best-effort).")
PY
else
  echo "NOT: AdminModule bulunamadı ($ADMIN_MODULE)."
  echo "Eğer admin modülleri AppModule üzerinden bağlanıyorsa sorun yok."
fi

# ---------------------------
# Run migration + generate
# ---------------------------
echo "==> Running prisma migrate + generate..."
cd apps/api
pnpm prisma migrate dev --name offer_system
pnpm prisma generate

echo
echo "==> DONE"
echo "Test endpoints:"
echo "  POST /admin/leads/:id/assign   (ADMIN)  body: {\"userId\":\"...\"}"
echo "  POST /leads/:leadId/offers     (USER assignedTo) body: {\"amount\":20000,\"currency\":\"TRY\",\"description\":\"...\"}"
echo "  POST /offers/:id/send          (USER)"
echo "  POST /admin/offers/:id/accept  (ADMIN)"
echo "  POST /admin/offers/:id/reject  (ADMIN)"
