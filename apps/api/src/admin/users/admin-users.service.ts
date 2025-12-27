import { Injectable } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AdminUsersService {
  constructor(private prisma: PrismaService) {}

  findAll() {
    return this.prisma.user.findMany({
      select: { id: true, email: true, role: true, createdAt: true },
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
}
