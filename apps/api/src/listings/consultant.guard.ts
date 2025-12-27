import { CanActivate, ExecutionContext, ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Role } from '@prisma/client';

@Injectable()
export class ConsultantGuard implements CanActivate {
  constructor(private prisma: PrismaService) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest();
    const userId = String(req.headers['x-user-id'] ?? '').trim();

    if (!userId) throw new UnauthorizedException('x-user-id header is required');

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, role: true },
    });

    if (!user) throw new UnauthorizedException('User not found');
    if (user.role !== Role.CONSULTANT && user.role !== Role.ADMIN) {
      throw new ForbiddenException('Only CONSULTANT/ADMIN');
    }

    req.user = user;
    return true;
  }
}
