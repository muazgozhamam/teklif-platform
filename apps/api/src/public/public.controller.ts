import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Logger,
  Post,
  Res,
} from '@nestjs/common';
import type { Response } from 'express';
import { PublicChatService } from './public-chat.service';

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
  constructor(private readonly publicChatService: PublicChatService) {}

  @Post('applications')
  @HttpCode(HttpStatus.CREATED)
  createApplication(@Body() body: ApplicationBody) {
    this.logger.log(
      `Application received type=${body?.type || 'UNKNOWN'} email=${body?.email || 'N/A'} phone=${body?.phone || 'N/A'}`,
    );
    return { ok: true };
  }

  @Post('chat/stream')
  async streamChat(
    @Body() body: { message?: string; history?: Array<{ role: 'user' | 'assistant' | 'system'; content: string }> },
    @Res() res: Response,
  ) {
    res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    res.flushHeaders();

    const writeSse = (event: string, data: Record<string, unknown>) => {
      res.write(`event: ${event}\n`);
      res.write(`data: ${JSON.stringify(data)}\n\n`);
    };

    await this.publicChatService.streamChat(
      {
        message: body?.message || '',
        history: body?.history || [],
      },
      {
        onDelta: (text) => writeSse('delta', { text }),
        onError: (message) => writeSse('error', { message }),
        onDone: () => writeSse('done', { ok: true }),
      },
    );

    res.end();
  }
}
