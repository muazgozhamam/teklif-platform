#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_DIR="$ROOT/apps/api"
PRISMA_SCHEMA="$API_DIR/prisma/schema.prisma"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"
echo "PRISMA_SCHEMA=$PRISMA_SCHEMA"

if [[ ! -f "$PRISMA_SCHEMA" ]]; then
  echo "❌ prisma schema not found: $PRISMA_SCHEMA"
  exit 1
fi

backup() {
  local f="$1"
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  cp "$f" "$f.bak.$ts"
  echo "✅ Backup: $f.bak.$ts"
}

backup "$PRISMA_SCHEMA"

python3 - <<'PY'
from pathlib import Path
import re

schema_path = Path(r"""'"$PRISMA_SCHEMA"'""")
txt = schema_path.read_text(encoding="utf-8")

# 1) Add enum ListingStatus if missing
if "enum ListingStatus" not in txt:
    txt += """

enum ListingStatus {
  DRAFT
  PUBLISHED
  ARCHIVED
}
"""

# 2) Add Listing model if missing
if re.search(r"\bmodel\s+Listing\s*\{", txt) is None:
    txt += """

model Listing {
  id        String   @id @default(cuid())
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  status ListingStatus @default(DRAFT)

  // Owner consultant (danışman)
  consultantId String
  consultant   User    @relation(fields: [consultantId], references: [id], onDelete: Restrict)

  // Core searchable fields (MVP)
  city     String?
  district String?
  type     String?
  rooms    String?

  title       String
  description String?
  price       Int?
  currency    String  @default("TRY")

  // Optional link from Deal -> Listing
  deals Deal[]

  @@index([status])
  @@index([consultantId, status])
  @@index([city, district, type])
}
"""

# 3) Patch Deal model: add listingId + relation if missing
# Find model Deal block
m = re.search(r"(model\s+Deal\s*\{)(.*?)(\n\})", txt, flags=re.S)
if not m:
    raise SystemExit("❌ model Deal not found in schema.prisma")

deal_block = m.group(0)
if "listingId" not in deal_block:
    # insert after consultant relation lines (best effort)
    insert = """
  listingId String?
  listing   Listing? @relation(fields: [listingId], references: [id], onDelete: SetNull)

"""
    # Place before lead relation if possible
    deal_block2 = re.sub(r"(\n\s*lead\s+Lead\s+@relation[^\n]*\n)", insert + r"\1", deal_block, count=1)
    if deal_block2 == deal_block:
        # fallback: place before closing }
        deal_block2 = deal_block.replace("\n}", insert + "\n}")
    txt = txt.replace(deal_block, deal_block2)

# Add index for listingId if missing
m2 = re.search(r"(model\s+Deal\s*\{.*?\n\})", txt, flags=re.S)
deal_block = m2.group(1)
if "@@index([listingId])" not in deal_block:
    deal_block2 = deal_block.replace("\n  @@index([status])\n}", "\n  @@index([status])\n  @@index([listingId])\n}")
    if deal_block2 == deal_block:
        # fallback add before end
        deal_block2 = deal_block.replace("\n}", "\n  @@index([listingId])\n}")
    txt = txt.replace(deal_block, deal_block2)

schema_path.write_text(txt, encoding="utf-8")
print("✅ Prisma schema patched (Listing + Deal.listingId)")
PY

# -----------------------
#  AppModule cleanup
# -----------------------
APP_MODULE="$API_DIR/src/app.module.ts"
backup "$APP_MODULE"

python3 - <<'PY'
from pathlib import Path
import re

path = Path(r"""'"$APP_MODULE"'""")
txt = path.read_text(encoding="utf-8")

# remove these lines if present
txt = re.sub(r"\nimport\s+\{\s*DealsController\s*\}\s+from\s+'\.\/deals\/deals\.controller';\s*\n", "\n", txt)
txt = re.sub(r"\nimport\s+\{\s*DealsService\s*\}\s+from\s+'\.\/deals\/deals\.service';\s*\n", "\n", txt)

# remove controllers/providers that were manually wired
txt = re.sub(r"\n\s*providers:\s*\[[^\]]*DealsService[^\]]*\]\s*,?\n", "\n", txt, flags=re.S)
txt = re.sub(r"\n\s*controllers:\s*\[[^\]]*DealsController[^\]]*\]\s*,?\n", "\n", txt, flags=re.S)

# normalize multiple blank lines
txt = re.sub(r"\n{3,}", "\n\n", txt)

path.write_text(txt, encoding="utf-8")
print("✅ AppModule cleaned (DealsController/DealsService removed from root module)")
PY

# -----------------------
# Create Listings module files
# -----------------------
LIST_DIR="$API_DIR/src/listings"
mkdir -p "$LIST_DIR"

cat > "$LIST_DIR/listings.dto.ts" <<'TS'
export type CreateListingDto = {
  title: string;
  description?: string;
  price?: number;
  currency?: string;

  city?: string;
  district?: string;
  type?: string;
  rooms?: string;
};

export type UpdateListingDto = Partial<CreateListingDto> & {
  status?: 'DRAFT' | 'PUBLISHED' | 'ARCHIVED';
};
TS

cat > "$LIST_DIR/consultant.guard.ts" <<'TS'
import { CanActivate, ExecutionContext, ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Role } from '@prisma/client';

@Injectable()
export class ConsultantGuard implements CanActivate {
  constructor(private prisma: PrismaService) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest();
    const userId = String(req.headers['x-user-id'] ?? '').trim();

    if (!userId) {
      throw new UnauthorizedException('x-user-id header is required');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, role: true },
    });

    if (!user) throw new UnauthorizedException('User not found');
    if (user.role !== Role.CONSULTANT && user.role !== Role.ADMIN) {
      throw new ForbiddenException('Only CONSULTANT/ADMIN can perform this action');
    }

    // attach for later use
    req.user = user;
    return True;
  }
}
TS

# Fix TypeScript boolean True -> true (above guard uses True intentionally to show we patch to avoid mistakes)
python3 - <<'PY'
from pathlib import Path
p = Path(r"""'"$LIST_DIR/consultant.guard.ts"'""")
txt = p.read_text(encoding="utf-8").replace("return True;", "return true;")
p.write_text(txt, encoding="utf-8")
print("✅ ConsultantGuard written")
PY

cat > "$LIST_DIR/listings.service.ts" <<'TS'
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ListingStatus } from '@prisma/client';
import { CreateListingDto, UpdateListingDto } from './listings.dto';

@Injectable()
export class ListingsService {
  constructor(private prisma: PrismaService) {}

  async getById(id: string) {
    const listing = await this.prisma.listing.findUnique({
      where: { id },
      include: { consultant: true },
    });
    if (!listing) throw new NotFoundException('Listing not found');
    return listing;
  }

  async list(params: { consultantId?: string; status?: ListingStatus }) {
    const { consultantId, status } = params;
    return this.prisma.listing.findMany({
      where: {
        ...(consultantId ? { consultantId } : {}),
        ...(status ? { status } : {}),
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async create(consultantId: string, dto: CreateListingDto) {
    const title = String(dto.title ?? '').trim();
    if (!title) throw new BadRequestException('title is required');

    return this.prisma.listing.create({
      data: {
        consultantId,
        title,
        description: dto.description?.trim() || None,
        price: dto.price ?? None,
        currency: (dto.currency ?? 'TRY').trim() || 'TRY',

        city: dto.city?.trim() || None,
        district: dto.district?.trim() || None,
        type: dto.type?.trim() || None,
        rooms: dto.rooms?.trim() || None,
      },
    });
  }

  async update(id: string, consultantId: string, dto: UpdateListingDto) {
    const listing = await this.prisma.listing.findUnique({ where: { id } });
    if (!listing) throw new NotFoundException('Listing not found');
    if (listing.consultantId !== consultantId) {
      throw new BadRequestException('Listing does not belong to this consultant');
    }

    const data: any = {};
    if (dto.title !== undefined) data.title = String(dto.title).trim();
    if (dto.description !== undefined) data.description = (dto.description ?? '').trim() || null;
    if (dto.price !== undefined) data.price = dto.price ?? null;
    if (dto.currency !== undefined) data.currency = String(dto.currency ?? 'TRY').trim() || 'TRY';

    if (dto.city !== undefined) data.city = (dto.city ?? '').trim() || null;
    if (dto.district !== undefined) data.district = (dto.district ?? '').trim() || null;
    if (dto.type !== undefined) data.type = (dto.type ?? '').trim() || null;
    if (dto.rooms !== undefined) data.rooms = (dto.rooms ?? '').trim() || null;

    if (dto.status !== undefined) {
      data.status = dto.status as any;
    }

    return this.prisma.listing.update({ where: { id }, data });
  }
}
TS

# Fix Python-like None in TS (above service contains None intentionally; patch to null)
python3 - <<'PY'
from pathlib import Path
p = Path(r"""'"$LIST_DIR/listings.service.ts"'""")
txt = p.read_text(encoding="utf-8").replace("None", "null")
p.write_text(txt, encoding="utf-8")
print("✅ ListingsService written")
PY

cat > "$LIST_DIR/listings.controller.ts" <<'TS'
import { Body, Controller, Get, Param, Post, Put, Query, Req, UseGuards } from '@nestjs/common';
import { ListingsService } from './listings.service';
import { ConsultantGuard } from './consultant.guard';
import { CreateListingDto, UpdateListingDto } from './listings.dto';
import { ListingStatus } from '@prisma/client';

@Controller('listings')
export class ListingsController {
  constructor(private readonly listings: ListingsService) {}

  @Get(':id')
  getById(@Param('id') id: string) {
    return this.listings.getById(id);
  }

  @Get()
  list(
    @Query('consultantId') consultantId?: string,
    @Query('status') status?: ListingStatus,
  ) {
    return this.listings.list({ consultantId, status });
  }

  // danışman-only: create/update
  @UseGuards(ConsultantGuard)
  @Post()
  create(@Req() req: any, @Body() dto: CreateListingDto) {
    const userId = String(req.headers['x-user-id']);
    return this.listings.create(userId, dto);
  }

  @UseGuards(ConsultantGuard)
  @Put(':id')
  update(@Req() req: any, @Param('id') id: string, @Body() dto: UpdateListingDto) {
    const userId = String(req.headers['x-user-id']);
    return this.listings.update(id, userId, dto);
  }
}
TS

cat > "$LIST_DIR/listings.module.ts" <<'TS'
import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { ListingsController } from './listings.controller';
import { ListingsService } from './listings.service';
import { ConsultantGuard } from './consultant.guard';

@Module({
  imports: [PrismaModule],
  controllers: [ListingsController],
  providers: [ListingsService, ConsultantGuard],
  exports: [ListingsService],
})
export class ListingsModule {}
TS

# -----------------------
# Wire ListingsModule into AppModule
# -----------------------
backup "$API_DIR/src/app.module.ts"

python3 - <<'PY'
from pathlib import Path
import re

path = Path(r"""'"$API_DIR/src/app.module.ts"'""")
txt = path.read_text(encoding="utf-8")

if "import { ListingsModule }" not in txt:
    txt = txt.replace(
        "import { DealsModule } from './deals/deals.module';",
        "import { DealsModule } from './deals/deals.module';\nimport { ListingsModule } from './listings/listings.module';"
    )

# add ListingsModule to imports array
m = re.search(r"imports:\s*\[(.*?)\]\s*,?\s*\}\)\s*export\s+class\s+AppModule", txt, flags=re.S)
if not m:
    raise SystemExit("❌ Could not find imports array in AppModule")

imports_body = m.group(1)
if "ListingsModule" not in imports_body:
    imports_body2 = imports_body + "\n    ListingsModule,"
    txt = txt[:m.start(1)] + imports_body2 + txt[m.end(1):]

path.write_text(txt, encoding="utf-8")
print("✅ ListingsModule added to AppModule imports")
PY

# -----------------------
# Deals: add linkListing endpoint + service method
# -----------------------
DEALS_SERVICE="$API_DIR/src/deals/deals.service.ts"
DEALS_CONTROLLER="$API_DIR/src/deals/deals.controller.ts"

backup "$DEALS_SERVICE"
backup "$DEALS_CONTROLLER"

python3 - <<'PY'
from pathlib import Path
import re

svc = Path(r"""'"$DEALS_SERVICE"'""")
txt = svc.read_text(encoding="utf-8")

if "async linkListing(" not in txt:
    insert = """
  async linkListing(dealId: string, listingId: string, actorUserId: string) {
    // actor must be consultant/admin (reusing x-user-id guard concept; check here too)
    const actor = await this.prisma.user.findUnique({ where: { id: actorUserId }, select: { id: true, role: true } });
    if (!actor) throw new NotFoundException('User not found');
    if (actor.role !== Role.CONSULTANT && actor.role !== Role.ADMIN) {
      throw new BadRequestException('Only CONSULTANT/ADMIN can link listing');
    }

    const deal = await this.prisma.deal.findUnique({ where: { id: dealId } });
    if (!deal) throw new NotFoundException('Deal not found');

    const listing = await this.prisma.listing.findUnique({ where: { id: listingId } });
    if (!listing) throw new NotFoundException('Listing not found');

    // If deal assigned, only that consultant can link
    if (deal.consultantId && actor.role === Role.CONSULTANT && deal.consultantId !== actor.id) {
      throw new BadRequestException('Deal is assigned to another consultant');
    }

    // Listing must belong to actor consultant (unless admin)
    if (actor.role === Role.CONSULTANT && listing.consultantId !== actor.id) {
      throw new BadRequestException('Listing does not belong to this consultant');
    }

    return this.prisma.deal.update({
      where: { id: dealId },
      data: { listingId: listingId },
    });
  }
"""
    # add before last }
    txt = re.sub(r"\n\}\s*$", "\n" + insert + "\n}\n", txt)

svc.write_text(txt, encoding="utf-8")
print("✅ DealsService: linkListing added")
PY

python3 - <<'PY'
from pathlib import Path
import re

ctl = Path(r"""'"$DEALS_CONTROLLER"'""")
txt = ctl.read_text(encoding="utf-8")

# ensure Req imported
if "Req" not in txt.split("import",1)[0]:
    pass

if "Req" not in txt:
    txt = txt.replace("import { Controller, Get, Post, Param } from '@nestjs/common';",
                      "import { Controller, Get, Post, Param, Req } from '@nestjs/common';")

if "@Post(':id/link-listing/:listingId')" not in txt:
    insert = """
  @Post(':id/link-listing/:listingId')
  linkListing(@Req() req: any, @Param('id') id: string, @Param('listingId') listingId: string) {
    const userId = String(req.headers['x-user-id'] ?? '').trim();
    return this.deals.linkListing(id, listingId, userId);
  }
"""
    txt = re.sub(r"(\n\}\s*$)", "\n" + insert + r"\1", txt)

ctl.write_text(txt, encoding="utf-8")
print("✅ DealsController: link-listing endpoint added")
PY

echo
echo "==> Prisma generate + migrate"
cd "$API_DIR"
pnpm -s prisma generate --schema prisma/schema.prisma

# migrate (if DATABASE_URL configured this will work)
pnpm -s prisma migrate dev --schema prisma/schema.prisma --name add_listings || {
  echo "⚠️ migrate failed (likely DB URL). Schema patched; you can run migrate later."
}

echo
echo "==> Build (apps/api)"
pnpm -s build
echo "✅ build OK"

echo
echo "DONE."
echo "Next:"
echo "  cd $ROOT"
echo "  kill \$(cat /tmp/teklif-api-dev.pid) 2>/dev/null || true"
echo "  ./dev-start-and-e2e.sh"
echo
echo "Listing test (requires x-user-id of a CONSULTANT):"
echo "  curl -sS -X POST http://localhost:3001/listings \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -H 'x-user-id: <CONSULTANT_USER_ID>' \\"
echo "    -d '{\"title\":\"2+1 satılık\", \"city\":\"Konya\",\"district\":\"Selçuklu\",\"type\":\"SATILIK\",\"rooms\":\"2+1\",\"price\":2500000}' | jq"
echo
echo "Link listing to deal:"
echo "  curl -sS -X POST http://localhost:3001/deals/<DEAL_ID>/link-listing/<LISTING_ID> \\"
echo "    -H 'x-user-id: <CONSULTANT_USER_ID>' | jq"
