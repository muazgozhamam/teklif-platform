import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';

const DEV_JWT_SECRET = 'dev-secret';


@Injectable()
export class AuthService {
  constructor(private prisma: PrismaService, private jwt: JwtService) {}

  async validateUser(email: string, password: string) {
    const ident = (email || '').toString().trim();
    if (!ident) return null;

    const user = await this.prisma.user.findUnique({
      where: { email: ident },
    });

    if (!user) return null;
    if (!user.password) return null;

    const ok = await bcrypt.compare(password, user.password);
    if (!ok) return null;

    return user;
  }
  async login(user: { id: string; role: string }) {
    return {
      access_token: this.jwt.sign({ sub: user.id, role: user.role }, { secret: DEV_JWT_SECRET }),
    };
  }
}
