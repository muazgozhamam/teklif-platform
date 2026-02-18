import {Body, Controller, Delete, Get, Param, Post, UseGuards, BadRequestException, Patch, Query} from '@nestjs/common';
import { Role } from '@prisma/client';
import { Roles } from '../../common/roles/roles.decorator';
import { RolesGuard } from '../../common/roles/roles.guard';
import { JwtAuthGuard } from '../../auth/jwt-auth.guard';
import { AdminUsersService } from './admin-users.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
@Controller('admin/users')
export class AdminUsersController {
  constructor(private users: AdminUsersService) {}

  @Get()
  list(@Query('q') q?: string) {
    return this.users.findAll(q);
  }

  @Post()
  create(@Body() body: { email: string; password: string; role?: 'USER' | 'ADMIN' }) {
    return this.users.create(body.email, body.password, body.role ?? 'USER');
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.users.remove(id);
  }

  @Patch(':id')
  patchUser(
    @Param('id') id: string,
    @Body() body: { role?: Role; isActive?: boolean },
  ) {
    return this.users.patchUser(id, {
      role: body?.role,
      isActive: body?.isActive,
    });
  }

  @Patch(':id/role')
  patchRole(
    @Param('id') id: string,
    @Body() body: { role?: Role; isActive?: boolean },
  ) {
    return this.users.patchUser(id, {
      role: body?.role,
      isActive: body?.isActive,
    });
  }

  @Post(':id/set-password')
  async setPassword(@Param('id') id: string, @Body() body: { password: string }) {
    const pw = (body?.password ?? '').toString().trim();
    if (!pw) {
      throw new BadRequestException('password is required');
    }
    return this.users.setPassword(id, pw);
  }
}
