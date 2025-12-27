#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd)"
API_DIR="$ROOT_DIR/apps/api"
SRC_DIR="$API_DIR/src"
PRISMA_SCHEMA="$API_DIR/prisma/schema.prisma"

if [ ! -d "$API_DIR" ]; then
  echo "ERROR: apps/api bulunamadı. Proje kökünde (teklif-platform) çalıştır."
  exit 1
fi
if [ ! -f "$PRISMA_SCHEMA" ]; then
  echo "ERROR: schema.prisma bulunamadı: $PRISMA_SCHEMA"
  exit 1
fi

export SRC_DIR
export PRISMA_SCHEMA

echo "==> Day4 remaining apply: START"

python3 - <<'PY'
import os, re, pathlib

def read(p):
  p = pathlib.Path(p)
  return p.read_text(encoding="utf-8") if p.exists() else ""

def write(p, s):
  p = pathlib.Path(p)
  p.parent.mkdir(parents=True, exist_ok=True)
  p.write_text(s, encoding="utf-8")

def patch_app_module(app_module_path, import_line, module_name):
  s = read(app_module_path)
  if not s:
    raise SystemExit(f"ERROR: {app_module_path} yok")

  changed = False

  # Ensure import exists
  if import_line not in s:
    lines = s.splitlines()
    last_import_idx = 0
    for i, line in enumerate(lines):
      if line.startswith("import "):
        last_import_idx = i
    lines.insert(last_import_idx + 1, import_line)
    s = "\n".join(lines) + ("\n" if not s.endswith("\n") else "")
    changed = True

  # Ensure module in @Module imports
  m2 = re.search(r"imports\s*:\s*\[([\s\S]*?)\]", s)
  if not m2:
    s = re.sub(r"@Module\(\s*\{", "@Module({\n  imports: [],", s, count=1)
    changed = True
    m2 = re.search(r"imports\s*:\s*\[([\s\S]*?)\]", s)

  inside = m2.group(1)
  if re.search(rf"\b{re.escape(module_name)}\b", inside) is None:
    new_inside = inside.rstrip()
    if new_inside.strip():
      if not new_inside.strip().endswith(","):
        new_inside = new_inside.rstrip() + ","
      new_inside = new_inside + f"\n    {module_name},\n  "
    else:
      new_inside = f"\n    {module_name},\n  "
    s = s[:m2.start(1)] + new_inside + s[m2.end(1):]
    changed = True

  if changed:
    write(app_module_path, s)
  return changed

schema = os.environ["PRISMA_SCHEMA"]
base = os.environ["SRC_DIR"]

schema_text = read(schema)

# enum CommissionStatus
if "enum CommissionStatus" not in schema_text:
  schema_text = schema_text.rstrip() + """

enum CommissionStatus {
  PENDING
  PAYABLE
  PAID
}
"""

# model CommissionLedger
if "model CommissionLedger" not in schema_text:
  schema_text = schema_text.rstrip() + """

model CommissionLedger {
  id               String           @id @default(cuid())
  dealId           String           @unique
  agentId          String
  grossAmount      Int
  commissionRate   Int
  commissionAmount Int
  status           CommissionStatus @default(PENDING)
  createdAt        DateTime         @default(now())
}
"""

# Deal.locked best-effort
if "model Deal" in schema_text and re.search(r"\n\s*locked\s+Boolean", schema_text) is None:
  schema_text = re.sub(
    r"(model\s+Deal\s*\{[\s\S]*?)(\n\})",
    r"\1\n  locked    Boolean   @default(false)\2",
    schema_text,
    count=1
  )

write(schema, schema_text)

# ---- Files ----
def w(path, content):
  write(os.path.join(base, path), content)

# commissions
w("commissions/dto/update-commission-status.dto.ts", """\
import { IsEnum } from 'class-validator';

export enum CommissionStatusDto {
  PENDING = 'PENDING',
  PAYABLE = 'PAYABLE',
  PAID = 'PAID',
}

export class UpdateCommissionStatusDto {
  @IsEnum(CommissionStatusDto)
  status!: CommissionStatusDto;
}
""")

w("commissions/commissions.service.ts", """\
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class CommissionsService {
  constructor(private readonly prisma: PrismaService) {}

  async listAll() {
    return this.prisma.commissionLedger.findMany({ orderBy: { createdAt: 'desc' } });
  }

  async listMine(agentId: string) {
    return this.prisma.commissionLedger.findMany({
      where: { agentId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async updateStatus(id: string, status: 'PENDING' | 'PAYABLE' | 'PAID') {
    const row = await this.prisma.commissionLedger.findUnique({ where: { id } });
    if (!row) throw new NotFoundException('COMMISSION_NOT_FOUND');

    if (row.status === 'PAID' && status !== 'PAID') {
      throw new BadRequestException('COMMISSION_STATUS_LOCKED');
    }

    const order = { PENDING: 1, PAYABLE: 2, PAID: 3 } as const;
    if (order[status] < order[row.status as keyof typeof order]) {
      throw new BadRequestException('COMMISSION_STATUS_CANNOT_GO_BACK');
    }

    return this.prisma.commissionLedger.update({
      where: { id },
      data: { status },
    });
  }
}
""")

w("commissions/commissions.controller.ts", """\
import { Body, Controller, Get, Param, Patch, Req, UseGuards } from '@nestjs/common';
import { CommissionsService } from './commissions.service';
import { UpdateCommissionStatusDto } from './dto/update-commission-status.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '../auth/role.enum';

@Controller()
export class CommissionsController {
  constructor(private readonly service: CommissionsService) {}

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  @Get('commissions')
  listAll() {
    return this.service.listAll();
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/commissions')
  listMine(@Req() req: any) {
    const agentId = req.user?.sub ?? req.user?.id;
    return this.service.listMine(agentId);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  @Patch('commissions/:id/status')
  updateStatus(@Param('id') id: string, @Body() dto: UpdateCommissionStatusDto) {
    return this.service.updateStatus(id, dto.status as any);
  }
}
""")

w("commissions/commissions.module.ts", """\
import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { CommissionsController } from './commissions.controller';
import { CommissionsService } from './commissions.service';

@Module({
  imports: [PrismaModule],
  controllers: [CommissionsController],
  providers: [CommissionsService],
})
export class CommissionsModule {}
""")

# deal-finalize
w("deal-finalize/deal-finalize.service.ts", """\
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class DealFinalizeService {
  constructor(private readonly prisma: PrismaService) {}

  async finalize(dealId: string) {
    return this.prisma.$transaction(async (tx) => {
      const deal: any = await tx.deal.findUnique({ where: { id: dealId } });
      if (!deal) throw new NotFoundException('DEAL_NOT_FOUND');

      if (deal.locked === true) {
        const ledger = await tx.commissionLedger.findUnique({ where: { dealId } });
        return { deal, ledger, alreadyLocked: true };
      }

      const amount = deal.amount;
      const commissionRate = deal.commissionRate;
      const agentId = deal.agentId;

      if (typeof amount !== 'number' || typeof commissionRate !== 'number' || !agentId) {
        throw new BadRequestException('DEAL_MISSING_AMOUNT_OR_RATE_OR_AGENT');
      }

      const lockedDeal = await tx.deal.update({
        where: { id: dealId },
        data: { locked: true },
      });

      const commissionAmount = Math.floor((amount * commissionRate) / 100);

      const ledger = await tx.commissionLedger.create({
        data: {
          dealId,
          agentId,
          grossAmount: amount,
          commissionRate,
          commissionAmount,
        },
      });

      return { deal: lockedDeal, ledger, alreadyLocked: false };
    });
  }
}
""")

w("deal-finalize/deal-finalize.controller.ts", """\
import { Controller, Param, Post, UseGuards } from '@nestjs/common';
import { DealFinalizeService } from './deal-finalize.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '../auth/role.enum';

@Controller('deals')
export class DealFinalizeController {
  constructor(private readonly service: DealFinalizeService) {}

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  @Post(':id/finalize')
  finalize(@Param('id') id: string) {
    return this.service.finalize(id);
  }
}
""")

w("deal-finalize/deal-finalize.module.ts", """\
import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { DealFinalizeController } from './deal-finalize.controller';
import { DealFinalizeService } from './deal-finalize.service';

@Module({
  imports: [PrismaModule],
  controllers: [DealFinalizeController],
  providers: [DealFinalizeService],
})
export class DealFinalizeModule {}
""")

# auth: only create if missing
auth_dir = pathlib.Path(base) / "auth"
auth_dir.mkdir(parents=True, exist_ok=True)

def write_if_missing(path, content):
  p = pathlib.Path(base) / path
  if p.exists():
    return
  p.parent.mkdir(parents=True, exist_ok=True)
  p.write_text(content, encoding="utf-8")

write_if_missing("auth/role.enum.ts", "export enum Role { ADMIN = 'ADMIN', USER = 'USER', AGENT = 'AGENT' }\n")
write_if_missing("auth/roles.decorator.ts", """\
import { SetMetadata } from '@nestjs/common';
import { Role } from './role.enum';
export const ROLES_KEY = 'roles';
export const Roles = (...roles: Role[]) => SetMetadata(ROLES_KEY, roles);
""")
write_if_missing("auth/roles.guard.ts", """\
import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from './roles.decorator';
import { Role } from './role.enum';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}
  canActivate(ctx: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<Role[]>(ROLES_KEY, [ctx.getHandler(), ctx.getClass()]) ?? [];
    if (required.length === 0) return true;
    const req = ctx.switchToHttp().getRequest();
    const role = req.user?.role;
    return required.includes(role);
  }
}
""")
write_if_missing("auth/jwt-auth.guard.ts", """\
import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}
""")

# patch app.module.ts
app_module = os.path.join(base, "app.module.ts")
changed = False
changed |= patch_app_module(app_module, "import { CommissionsModule } from './commissions/commissions.module';", "CommissionsModule")
changed |= patch_app_module(app_module, "import { DealFinalizeModule } from './deal-finalize/deal-finalize.module';", "DealFinalizeModule")

print("PATCH app.module.ts:", "changed" if changed else "no-op")
print("OK: files generated/updated")
PY

echo "==> Prisma migrate (Day4 remaining)"
cd "$API_DIR"
pnpm prisma migrate dev --name day4_remaining --skip-generate
pnpm prisma generate

echo "==> Day4 remaining apply: DONE"
echo "Next: restart api -> pnpm -C apps/api start:dev"
