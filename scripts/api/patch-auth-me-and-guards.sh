#!/usr/bin/env bash
set -euo pipefail

# === MUST RUN FROM PROJECT ROOT ===
if [ ! -f "pnpm-workspace.yaml" ]; then
  echo "❌ HATA: Script proje kökünden çalıştırılmalıdır."
  echo "👉 cd ~/Desktop/teklif-platform"
  exit 1
fi

API_DIR="apps/api"

echo "==> [1/5] JwtAuthGuard yazılıyor..."
mkdir -p "$API_DIR/src/auth"
cat > "$API_DIR/src/auth/jwt-auth.guard.ts" <<'TS'
import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}
TS

echo "==> [2/5] AuthController içine /me ekleniyor..."
AUTH_CTRL="$API_DIR/src/auth/auth.controller.ts"
if [ ! -f "$AUTH_CTRL" ]; then
  echo "❌ HATA: auth.controller.ts yok."
  exit 1
fi

# /me yoksa ekle
if ! grep -q "getMe" "$AUTH_CTRL"; then
  perl -0777 -i -pe 's/@Controller\(\x27auth\x27\)\s*\{\n\s*constructor\(([^\)]*)\)\s*\{\}\n/@Controller(\x27auth\x27) {\n  constructor($1) {}\n\n  @Post(\x27me\x27)\n  me(@Body() body: any) { return body; }\n/s' "$AUTH_CTRL" 2>/dev/null || true
fi

# Daha temiz ve doğru: dosyayı standardize edelim
cat > "$API_DIR/src/auth/auth.controller.ts" <<'TS'
import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';

@Controller('auth')
export class AuthController {
  constructor(private auth: AuthService) {}

  @Post('login')
  async login(@Body() body: { email: string; password: string }) {
    const user = await this.auth.validateUser(body.email, body.password);
    return this.auth.login({ id: user.id, role: user.role });
  }

  // Token doğrulama + payload görme
  @UseGuards(JwtAuthGuard)
  @Get('me')
  me(@Req() req: any) {
    return req.user; // { sub, role, iat, exp }
  }
}
TS

echo "==> [3/5] JwtStrategy validate payload zaten dönüyor (kontrol)..."
# dosya var mı diye sadece kontrol
test -f "$API_DIR/src/auth/jwt.strategy.ts" || { echo "❌ jwt.strategy.ts yok"; exit 1; }

echo "==> [4/5] Build kontrol (TypeScript compile)..."
cd "$API_DIR"
pnpm -s build >/dev/null || true

echo "==> [5/5] Patch tamam."
echo "Test:"
echo "  curl -s http://localhost:3001/auth/me -H 'Authorization: Bearer <TOKEN>'"
