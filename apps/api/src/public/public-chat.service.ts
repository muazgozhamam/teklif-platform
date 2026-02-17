import { Injectable, Logger } from '@nestjs/common';

type ChatRole = 'user' | 'assistant' | 'system';

type ChatMessage = {
  role: ChatRole;
  content: string;
};

type StreamHandlers = {
  onDelta: (text: string) => void;
  onError: (message: string) => void;
  onDone: () => void;
};

type ChatStreamInput = {
  message: string;
  history?: ChatMessage[];
};

@Injectable()
export class PublicChatService {
  private readonly logger = new Logger(PublicChatService.name);

  private readonly systemPrompt = [
    'Sen SatDedi Asistanı’sın.',
    'Kullanıcıya Türkçe, doğal ve güven veren bir tonda yanıt ver.',
    'Yanıtlar kısa/orta dengede olsun; gerektiğinde net adım listesi ver.',
    'Emlak, satış/kiralama, danışmanlık, iş ortaklığı bağlamına odaklan.',
    'Kesin hukuki/finansal taahhüt verme; kritik kararlar için uzman doğrulaması öner.',
    'Kullanıcı sorusu belirsizse tek bir netleştirici soru sor.',
  ].join(' ');

  private getApiKey(): string {
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) throw new Error('OPENAI_API_KEY tanımlı değil.');
    return apiKey;
  }

  private normalizeInput(input: ChatStreamInput): { message: string; history: ChatMessage[] } {
    const message = (input.message || '').trim();
    const history = (input.history || [])
      .filter((m) => m && typeof m.content === 'string' && m.content.trim().length > 0)
      .slice(-12);
    return { message, history };
  }

  private buildOpenAiInput(message: string, history: ChatMessage[]) {
    return [
      {
        role: 'system',
        content: [{ type: 'input_text', text: this.systemPrompt }],
      },
      ...history.map((m) => ({
        role: m.role === 'assistant' ? 'assistant' : 'user',
        content: [
          m.role === 'assistant'
            ? { type: 'output_text', text: m.content }
            : { type: 'input_text', text: m.content },
        ],
      })),
      {
        role: 'user',
        content: [{ type: 'input_text', text: message }],
      },
    ];
  }

  async completeChat(input: ChatStreamInput): Promise<string> {
    const apiKey = this.getApiKey();
    const { message, history } = this.normalizeInput(input);
    if (!message) throw new Error('Boş mesaj gönderilemez.');

    const model = process.env.OPENAI_CHAT_MODEL || 'gpt-4.1-mini';
    const response = await fetch('https://api.openai.com/v1/responses', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        stream: false,
        input: this.buildOpenAiInput(message, history),
      }),
    });

    const json = await response.json().catch(() => ({} as Record<string, unknown>));
    if (!response.ok) {
      this.logger.error(`OpenAI sync failed status=${response.status} body=${JSON.stringify(json)}`);
      throw new Error('Yanıt alınamadı. Lütfen tekrar dene.');
    }

    const direct = typeof (json as { output_text?: unknown }).output_text === 'string'
      ? ((json as { output_text: string }).output_text || '').trim()
      : '';
    if (direct) return direct;

    const output = Array.isArray((json as { output?: unknown }).output) ? (json as { output: unknown[] }).output : [];
    const textParts: string[] = [];

    for (const item of output) {
      if (!item || typeof item !== 'object') continue;
      const content = Array.isArray((item as { content?: unknown }).content) ? (item as { content: unknown[] }).content : [];
      for (const c of content) {
        if (!c || typeof c !== 'object') continue;
        if ((c as { type?: unknown }).type === 'output_text' && typeof (c as { text?: unknown }).text === 'string') {
          textParts.push((c as { text: string }).text);
        }
      }
    }

    return textParts.join('').trim();
  }

  async streamChat(input: ChatStreamInput, handlers: StreamHandlers): Promise<void> {
    let apiKey = '';
    try {
      apiKey = this.getApiKey();
    } catch (err) {
      handlers.onError('OPENAI_API_KEY tanımlı değil.');
      handlers.onDone();
      return;
    }

    const { message, history } = this.normalizeInput(input);
    if (!message) {
      handlers.onError('Boş mesaj gönderilemez.');
      handlers.onDone();
      return;
    }

    const model = process.env.OPENAI_CHAT_MODEL || 'gpt-4.1-mini';
    const openAiInput = this.buildOpenAiInput(message, history);

    const response = await fetch('https://api.openai.com/v1/responses', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        stream: true,
        input: openAiInput,
      }),
    });

    if (!response.ok || !response.body) {
      const errText = await response.text().catch(() => '');
      this.logger.error(`OpenAI upstream failed status=${response.status} body=${errText}`);
      handlers.onError('Yanıt alınamadı. Lütfen tekrar dene.');
      handlers.onDone();
      return;
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';

    try {
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });

        let boundary = buffer.indexOf('\n\n');
        while (boundary !== -1) {
          const chunk = buffer.slice(0, boundary).trim();
          buffer = buffer.slice(boundary + 2);
          this.processSseChunk(chunk, handlers);
          boundary = buffer.indexOf('\n\n');
        }
      }
    } catch (err) {
      this.logger.warn(`stream read interrupted: ${(err as Error).message}`);
      handlers.onError('Akış kesildi. Tekrar deneyebilirsin.');
    } finally {
      handlers.onDone();
    }
  }

  private processSseChunk(rawChunk: string, handlers: StreamHandlers) {
    if (!rawChunk) return;

    const lines = rawChunk.split('\n');
    for (const line of lines) {
      if (!line.startsWith('data:')) continue;

      const payload = line.slice(5).trim();
      if (!payload || payload === '[DONE]') return;

      try {
        const event = JSON.parse(payload) as { type?: string; delta?: string; message?: string };
        if (event.type === 'response.output_text.delta' && typeof event.delta === 'string') {
          handlers.onDelta(event.delta);
          continue;
        }

        if (event.type === 'error') {
          handlers.onError(event.message || 'Model hatası oluştu.');
        }
      } catch {
        // ignore malformed chunk
      }
    }
  }
}
