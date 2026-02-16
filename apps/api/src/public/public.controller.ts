import {
  BadRequestException,
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  InternalServerErrorException,
  Logger,
  Post,
  Req,
  Res,
} from '@nestjs/common';
import type { Request, Response } from 'express';
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

type ChatRole = 'user' | 'assistant' | 'system';
type ChatMessage = { role: ChatRole; content: string };
type ChatStreamBody =
  | { messages?: ChatMessage[] }
  | { message?: string; history?: ChatMessage[] };

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
    @Body() body: ChatStreamBody,
    @Req() req: Request,
    @Res() res: Response,
  ) {
    const normalized = this.normalizeChatPayload(body);

    if (!normalized.message) {
      throw new BadRequestException(
        'Invalid chat payload. Use either { messages: [{ role, content }] } or { message, history }.',
      );
    }

    res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    res.flushHeaders();
    res.write('retry: 15000\n\n');

    let disconnected = false;
    const heartbeat = setInterval(() => {
      if (disconnected || res.writableEnded) return;
      res.write(': heartbeat\n\n');
    }, 15_000);

    const cleanup = (reason: 'req-close' | 'res-close' | 'res-finish' | 'finally') => {
      if (disconnected) return;
      disconnected = true;
      clearInterval(heartbeat);
      if (reason === 'req-close' || reason === 'res-close') {
        this.logger.log('SSE client disconnected: /public/chat/stream');
      }
      if (!res.writableEnded) res.end();
    };

    req.on('close', () => cleanup('req-close'));
    res.on('close', () => cleanup('res-close'));
    res.on('finish', () => cleanup('res-finish'));

    const writeSse = (event: string, data: Record<string, unknown>) => {
      if (disconnected || res.writableEnded) return;
      res.write(`event: ${event}\n`);
      res.write(`data: ${JSON.stringify(data)}\n\n`);
    };

    try {
      await this.publicChatService.streamChat(
        normalized,
        {
          onDelta: (text) => writeSse('delta', { text }),
          onError: (message) => writeSse('error', { message }),
          onDone: () => writeSse('done', { ok: true }),
        },
      );
    } finally {
      cleanup('finally');
    }
  }

  @Post('chat')
  async chat(@Body() body: ChatStreamBody) {
    const normalized = this.normalizeChatPayload(body);
    if (!normalized.message) {
      throw new BadRequestException(
        'Invalid chat payload. Use either { messages: [{ role, content }] } or { message, history }.',
      );
    }

    try {
      const text = await this.publicChatService.completeChat(normalized);
      return { ok: true, text };
    } catch (err) {
      throw new InternalServerErrorException((err as Error)?.message || 'Chat failed');
    }
  }

  private normalizeChatPayload(body: ChatStreamBody | null | undefined): { message: string; history: ChatMessage[] } {
    if (!body || typeof body !== 'object') return { message: '', history: [] };

    const isValidRole = (role: unknown): role is ChatRole =>
      role === 'user' || role === 'assistant' || role === 'system';

    const normalizeMessages = (items: unknown): ChatMessage[] => {
      if (!Array.isArray(items)) return [];
      return items
        .filter((m) => !!m && typeof m === 'object')
        .map((m) => m as Partial<ChatMessage>)
        .filter((m): m is ChatMessage => isValidRole(m.role) && typeof m.content === 'string')
        .map((m) => ({ role: m.role, content: m.content.trim() }))
        .filter((m) => m.content.length > 0);
    };

    // Preferred format: { messages: [{ role, content }, ...] }
    if ('messages' in body && Array.isArray(body.messages)) {
      const messages = normalizeMessages(body.messages);
      if (!messages.length) return { message: '', history: [] };

      const lastUserIndex = messages.map((m) => m.role).lastIndexOf('user');
      if (lastUserIndex === -1) return { message: '', history: [] };

      const target = messages[lastUserIndex];
      const history = messages.slice(0, lastUserIndex);
      return { message: target.content, history };
    }

    // Legacy format: { message, history }
    const message = 'message' in body && typeof body.message === 'string' ? body.message.trim() : '';
    const history = 'history' in body ? normalizeMessages(body.history) : [];
    return { message, history };
  }
}
