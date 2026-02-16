import { Body, Controller, HttpCode, HttpStatus, Logger, Post } from '@nestjs/common';

type ApplicationBody = {
  type: 'CONSULTANT' | 'PARTNER';
  fullName: string;
  email: string;
  phone: string;
  city?: string;
  district?: string;
  data?: Record<string, unknown>;
};

@Controller('public')
export class PublicController {
  private readonly logger = new Logger(PublicController.name);

  @Post('applications')
  @HttpCode(HttpStatus.CREATED)
  createApplication(@Body() body: ApplicationBody) {
    this.logger.log(
      `Application received type=${body?.type || 'UNKNOWN'} email=${body?.email || 'N/A'} phone=${body?.phone || 'N/A'}`,
    );
    return { ok: true };
  }
}
