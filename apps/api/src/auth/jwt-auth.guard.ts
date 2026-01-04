import { Injectable, Logger, ExecutionContext } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import type { Request } from 'express';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  private readonly logger = new Logger(JwtAuthGuard.name);

  handleRequest(
    err: unknown,
    user: unknown,
    info: unknown,
    context: ExecutionContext,
  ) {
    const req = context.switchToHttp().getRequest<Request>();
    const auth = req.headers.authorization;

    const infoStr =
      info instanceof Error
        ? `${info.name}: ${info.message}`
        : info
          ? JSON.stringify(info)
          : 'none';

    this.logger.log(
      `handleRequest authPresent=${auth ? 'YES' : 'no'} userPresent=${user ? 'YES' : 'no'} err=${err ? 'YES' : 'no'} info=${infoStr}`,
    );

    // Pass through to default implementation (casts are fine here)
    // eslint-disable-next-line @typescript-eslint/no-unsafe-return
    return super.handleRequest(err as any, user as any, info as any, context);
  }
}
