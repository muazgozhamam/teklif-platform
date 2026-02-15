import { BadRequestException, Controller, ForbiddenException, Get, Param, Req, UseGuards } from '@nestjs/common';
import { AuditEntityType } from '@prisma/client';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AuditService } from './audit.service';

type ReqWithUser = {
  user?: { sub?: string; id?: string; role?: string };
};

@UseGuards(JwtAuthGuard)
@Controller('audit')
export class AuditController {
  constructor(private readonly audit: AuditService) {}

  @Get('entity/:entityType/:entityId')
  async byEntity(
    @Req() req: ReqWithUser,
    @Param('entityType') entityTypeRaw: string,
    @Param('entityId') entityId: string,
  ) {
    const entityType = this.parseEntityType(entityTypeRaw);
    const actor = this.getActor(req);
    if (entityType === AuditEntityType.LEAD) {
      await this.audit.assertCanReadLead(actor, entityId);
    } else if (entityType === AuditEntityType.DEAL) {
      await this.audit.assertCanReadDeal(actor, entityId);
    } else if (entityType === AuditEntityType.LISTING) {
      await this.audit.assertCanReadListing(actor, entityId);
    } else if (actor.role !== 'ADMIN') {
      throw new ForbiddenException('Forbidden resource');
    }
    return this.audit.listByEntity(entityType, entityId, 'asc');
  }

  @Get('me')
  async me(@Req() req: ReqWithUser) {
    const actor = this.getActor(req);
    return this.audit.listAdmin({ actorUserId: actor.userId, take: 50, skip: 0 });
  }

  private getActor(req: ReqWithUser) {
    const userId = String(req.user?.sub ?? req.user?.id ?? '').trim();
    const role = String(req.user?.role ?? '').trim().toUpperCase();
    if (!userId || !role) {
      throw new BadRequestException('Missing user context');
    }
    return { userId, role };
  }

  private parseEntityType(v: string): AuditEntityType {
    const up = String(v || '').trim().toUpperCase();
    const values = new Set<string>(Object.values(AuditEntityType));
    if (!values.has(up)) {
      throw new BadRequestException('Invalid entityType');
    }
    return up as AuditEntityType;
  }
}
