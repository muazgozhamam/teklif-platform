#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API="$ROOT/apps/api"
DASH="$ROOT/apps/dashboard"

echo "==> Sanity..."
test -d "$API/src" || { echo "API not found"; exit 1; }
test -d "$DASH/app" || { echo "Dashboard not found"; exit 1; }

###############################################################################
# API: Admin module (list users + set role)
###############################################################################
echo "==> API: writing AdminModule..."

mkdir -p "$API/src/admin"

cat > "$API/src/admin/admin.dto.ts" <<'TS'
import { IsIn, IsString } from 'class-validator';

export class SetUserRoleDto {
  @IsString()
  @IsIn(['HUNTER', 'AGENT', 'BROKER', 'ADMIN'])
  role!: 'HUNTER' | 'AGENT' | 'BROKER' | 'ADMIN';
}
TS

cat > "$API/src/admin/admin.controller.ts" <<'TS'
import { Body, Controller, Get, Param, Patch, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../common/roles.decorator';
import { RolesGuard } from '../common/roles.guard';
import { PrismaService } from '../prisma/prisma.service';
import { SetUserRoleDto } from './admin.dto';

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminController {
  constructor(private prisma: PrismaService) {}

  @Get('users')
  async listUsers() {
    return this.prisma.user.findMany({
      orderBy: { createdAt: 'desc' as any },
      select: { id: true, email: true, name: true, role: true, invitedById: true, createdAt: true },
    });
  }

  @Patch('users/:id/role')
  async setRole(@Param('id') id: string, @Body() dto: SetUserRoleDto) {
    return this.prisma.user.update({
      where: { id },
      data: { role: dto.role as any },
      select: { id: true, email: true, name: true, role: true, invitedById: true, createdAt: true },
    });
  }
}
TS

cat > "$API/src/admin/admin.module.ts" <<'TS'
import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { AdminController } from './admin.controller';

@Module({
  imports: [PrismaModule],
  controllers: [AdminController],
})
export class AdminModule {}
TS

echo "==> API: ensuring Roles decorator/guard exist..."
# If these files already exist, leave them. If not, create minimal versions.
if [ ! -f "$API/src/common/roles.decorator.ts" ]; then
  mkdir -p "$API/src/common"
  cat > "$API/src/common/roles.decorator.ts" <<'TS'
import { SetMetadata } from '@nestjs/common';
export const ROLES_KEY = 'roles';
export const Roles = (...roles: string[]) => SetMetadata(ROLES_KEY, roles);
TS
fi

if [ ! -f "$API/src/common/roles.guard.ts" ]; then
  mkdir -p "$API/src/common"
  cat > "$API/src/common/roles.guard.ts" <<'TS'
import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from './roles.decorator';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!requiredRoles || requiredRoles.length === 0) return true;

    const req = context.switchToHttp().getRequest();
    const user = req.user;
    if (!user?.role) return false;

    return requiredRoles.includes(user.role);
  }
}
TS
fi

echo "==> API: adding AdminModule to AppModule imports..."
python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/app.module.ts")
s = p.read_text(encoding="utf-8")

# Ensure import exists
if "AdminModule" not in s:
    # add import after existing imports
    s = re.sub(r"(from\s+'\.\/auth\/auth\.module';\s*)",
               r"\1import { AdminModule } from './admin/admin.module';\n",
               s, count=1)

# Add AdminModule into imports array
# Find "imports: [ ... ]"
m = re.search(r"imports\s*:\s*\[(.*?)\]", s, flags=re.S)
if not m:
    raise SystemExit("Could not find imports: [ ] in AppModule")

block = m.group(1)
if "AdminModule" not in block:
    # append before closing
    new_block = block.strip()
    if new_block and not new_block.endswith(","):
        new_block += ","
    new_block += "\n    AdminModule,\n  "
    s = s[:m.start(1)] + new_block + s[m.end(1):]

p.write_text(s, encoding="utf-8")
print("AppModule updated with AdminModule")
PY

###############################################################################
# Dashboard: /admin/users page
###############################################################################
echo "==> Dashboard: writing /admin/users page..."
mkdir -p "$DASH/app/admin/users"

cat > "$DASH/app/admin/users/page.tsx" <<'TSX'
'use client';

import { useEffect, useState } from 'react';
import { api, clearToken } from '@/lib/api';
import { requireAuth } from '@/lib/auth';

type UserRow = {
  id: string;
  email: string;
  name: string | null;
  role: string;
  invitedById: string | null;
  createdAt: string;
};

const ROLES = ['HUNTER', 'AGENT', 'BROKER', 'ADMIN'] as const;

export default function AdminUsersPage() {
  const [items, setItems] = useState<UserRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState<string | null>(null);

  async function load() {
    setLoading(true);
    setMsg(null);
    try {
      const res = await api.get('/admin/users');
      setItems(res.data);
    } catch (err: any) {
      setMsg(err?.response?.data?.message ?? 'Failed to load users (Admin only).');
    } finally {
      setLoading(false);
    }
  }

  async function setRole(userId: string, role: string) {
    setMsg(null);
    try {
      const res = await api.patch(`/admin/users/${userId}/role`, { role });
      setItems((prev) => prev.map((u) => (u.id === userId ? res.data : u)));
      setMsg('Role updated.');
    } catch (err: any) {
      setMsg(err?.response?.data?.message ?? 'Role update failed.');
    }
  }

  useEffect(() => {
    requireAuth();
    load();
  }, []);

  return (
    <div style={{ maxWidth: 1100, margin: '24px auto', fontFamily: 'system-ui' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12 }}>
        <h1>Admin • Users ({items.length})</h1>
        <div style={{ display: 'flex', gap: 8 }}>
          <button onClick={load}>Refresh</button>
          <button
            onClick={() => {
              clearToken();
              window.location.href = '/login';
            }}
          >
            Logout
          </button>
          <button onClick={() => (window.location.href = '/broker/leads/pending')}>Broker</button>
        </div>
      </div>

      {loading && <p>Loading...</p>}
      {msg && <p style={{ color: msg === 'Role updated.' ? 'green' : 'crimson' }}>{msg}</p>}

      <div style={{ display: 'grid', gap: 10 }}>
        {items.map((u) => (
          <div key={u.id} style={{ border: '1px solid #333', borderRadius: 10, padding: 12 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, alignItems: 'center' }}>
              <div>
                <div style={{ fontWeight: 700 }}>{u.name ?? '(No name)'} — {u.email}</div>
                <div style={{ color: '#999', fontSize: 12 }}>
                  id={u.id} • invitedById={u.invitedById ?? '-'} • createdAt={u.createdAt}
                </div>
              </div>

              <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                <select
                  defaultValue={u.role}
                  onChange={(e) => setRole(u.id, e.target.value)}
                  style={{ padding: 8 }}
                >
                  {ROLES.map((r) => (
                    <option key={r} value={r}>
                      {r}
                    </option>
                  ))}
                </select>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
TSX

echo "==> Done."
echo "Next:"
echo "  1) Restart API:       cd apps/api && pnpm dev"
echo "  2) Restart Dashboard: cd apps/dashboard && pnpm dev --port 3000"
echo "Open:"
echo "  http://localhost:3000/admin/users"
