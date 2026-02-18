import { Injectable } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { Role } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AdminUsersService {
  constructor(private prisma: PrismaService) {}

  findAll(q?: string) {
    const query = String(q || '').trim();
    return this.prisma.user.findMany({
      where: query
        ? {
            OR: [
              { email: { contains: query, mode: 'insensitive' } },
              { name: { contains: query, mode: 'insensitive' } },
            ],
          }
        : undefined,
      orderBy: { createdAt: 'desc' },
      select: { id: true, email: true, name: true, role: true, isActive: true, createdAt: true },
    });
  }

  async create(email: string, password: string, role: 'USER' | 'ADMIN') {
    const hash = await bcrypt.hash(password, 10);
    return this.prisma.user.create({
      data: { email, password: hash, role },
      select: { id: true, email: true, role: true },
    });
  }

  remove(id: string) {
    return this.prisma.user.delete({ where: { id } });
  }

  async patchUser(id: string, patch: { role?: Role; isActive?: boolean }) {
    const data: { role?: Role; isActive?: boolean } = {};
    if (patch.role) data.role = patch.role;
    if (typeof patch.isActive === 'boolean') data.isActive = patch.isActive;

    return this.prisma.user.update({
      where: { id },
      data,
      select: { id: true, email: true, name: true, role: true, isActive: true, createdAt: true },
    });
  }

  async setPassword(id: string, password: string) {
    const pw = (password ?? '').toString().trim();
    if (!pw) {
      throw new Error('password is required');
    }
    const hash = await bcrypt.hash(pw, 10);
    await this.prisma.user.update({
      where: { id },
      data: { password: hash },
    });
    return { ok: true };
  }
}
