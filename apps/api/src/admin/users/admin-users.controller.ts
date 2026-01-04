import {Body, Controller, Delete, Get, Param, Post, UseGuards, BadRequestException} from '@nestjs/common';
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
  list() {
    return this.users.findAll();
  }

  @Post()
  create(@Body() body: { email: string; password: string; role?: 'USER' | 'ADMIN' }) {
    return this.users.create(body.email, body.password, body.role ?? 'USER');
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.users.remove(id);
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
