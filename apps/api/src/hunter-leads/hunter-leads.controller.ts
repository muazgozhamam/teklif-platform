import {
  BadRequestException,
  Controller,
  ForbiddenException,
  Get,
  Post,
  Body,
  Req,
  UseGuards,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

type ReqWithUser = {
  user?: { id?: string; sub?: string; role?: string };
};

@Controller('hunter/leads')
@UseGuards(JwtAuthGuard)
export class HunterLeadsController {
  constructor(private prisma: PrismaService) {}

  private assertHunter(req: ReqWithUser) {
    const role = String(req.user?.role || '').toUpperCase();
    if (role !== 'HUNTER') {
      throw new ForbiddenException();
    }
  }

  @Post()
  async create(
    @Req() req: ReqWithUser,
    @Body() body: { initialText?: string },
  ) {
    this.assertHunter(req);

    const initialText = String(body?.initialText || '').trim();
    if (!initialText) {
      throw new BadRequestException('initialText required');
    }

    const userId = String(req.user?.id ?? req.user?.sub ?? '').trim() || null;

    const lead = await this.prisma.lead.create({
      data: {
        initialText,
        status: 'OPEN',
        sourceRole: 'HUNTER',
        sourceUserId: userId,
      },
      select: { id: true, status: true, createdAt: true },
    });

    return lead;
  }

  @Get()
  async listMine(@Req() req: ReqWithUser) {
    this.assertHunter(req);

    const userId = String(req.user?.id ?? req.user?.sub ?? '').trim();
    if (!userId) return [];

    const leads = await this.prisma.lead.findMany({
      where: { sourceRole: 'HUNTER', sourceUserId: userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
      select: { id: true, status: true, createdAt: true, initialText: true },
    });

    return leads;
  }
}
