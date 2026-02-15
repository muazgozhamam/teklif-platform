import { BadRequestException, Body, Controller, Delete, Get, Param, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';
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
  list(@Query('take') take?: string, @Query('skip') skip?: string, @Query('q') q?: string) {
    return this.users.findAll({
      take: take ? Number(take) : undefined,
      skip: skip ? Number(skip) : undefined,
      q,
    });
  }

  @Get('paged')
  listPaged(@Query('take') take?: string, @Query('skip') skip?: string, @Query('q') q?: string) {
    return this.users.findAllPaged({
      take: take ? Number(take) : undefined,
      skip: skip ? Number(skip) : undefined,
      q,
    });
  }

  @Post()
  create(@Body() body: { email: string; password: string; role?: Role }) {
    const role = this.parseRole(body.role);
    return this.users.create(body.email, body.password, role ?? Role.USER);
  }

  @Patch(':id')
  patchUser(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { role?: Role | string; isActive?: boolean },
  ) {
    const role = this.parseRole(body.role);
    const isActive = body.isActive;
    return this.users.patchUser(id, { role, isActive }, this.actor(req));
  }

  @Patch(':id/role')
  patchUserRole(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { role?: Role | string },
  ) {
    const role = this.parseRole(body.role);
    if (!role) {
      throw new BadRequestException('role is required');
    }
    return this.users.patchUser(id, { role }, this.actor(req));
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

  private actor(req: { user?: { sub?: string; id?: string; role?: string } }) {
    return {
      actorUserId: String(req?.user?.sub ?? req?.user?.id ?? '').trim() || null,
      actorRole: String(req?.user?.role ?? '').trim().toUpperCase() || null,
    };
  }

  private parseRole(role?: Role | string): Role | undefined {
    if (role === undefined || role === null || String(role).trim() === '') return undefined;
    const v = String(role).trim().toUpperCase();
    const allowed = new Set<Role>([Role.USER, Role.ADMIN, Role.BROKER, Role.CONSULTANT, Role.HUNTER]);
    if (!allowed.has(v as Role)) {
      throw new BadRequestException('Invalid role');
    }
    return v as Role;
  }
}
