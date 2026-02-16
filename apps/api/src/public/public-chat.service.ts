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

  async streamChat(input: ChatStreamInput, handlers: StreamHandlers): Promise<void> {
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) {
      handlers.onError('OPENAI_API_KEY tanımlı değil.');
      handlers.onDone();
      return;
    }

    const message = (input.message || '').trim();
    if (!message) {
      handlers.onError('Boş mesaj gönderilemez.');
      handlers.onDone();
      return;
    }

    const model = process.env.OPENAI_CHAT_MODEL || 'gpt-4.1-mini';
    const history = (input.history || [])
      .filter((m) => m && typeof m.content === 'string' && m.content.trim().length > 0)
      .slice(-12);

    const openAiInput = [
      {
        role: 'system',
        content: [{ type: 'input_text', text: this.systemPrompt }],
      },
      ...history.map((m) => ({
        role: m.role === 'assistant' ? 'assistant' : 'user',
        content: [{ type: 'input_text', text: m.content }],
      })),
      {
        role: 'user',
        content: [{ type: 'input_text', text: message }],
      },
    ];

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

