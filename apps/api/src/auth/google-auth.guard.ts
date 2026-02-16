import { ExecutionContext, Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AuthService } from './auth.service';

@Injectable()
export class GoogleAuthGuard extends AuthGuard('google') {
  constructor(private readonly authService: AuthService) {
    super();
  }

  getAuthenticateOptions(context: ExecutionContext) {
    const req = context.switchToHttp().getRequest<{ query?: Record<string, string | undefined>; path?: string }>();
    const isCallback = String(req?.path || '').includes('/callback');
    if (isCallback) {
      return { session: false };
    }

    const redirect = req?.query?.redirect;
    return {
      session: false,
      scope: ['email', 'profile'],
      state: this.authService.createOAuthState(redirect),
    };
  }
}
