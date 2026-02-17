import { NextRequest } from "next/server";

export const runtime = "nodejs";

const MAX_GUEST_MESSAGES = 5;
const GUEST_COUNT_COOKIE = "satdedi_guest_chat_count";

const SALES_INSTRUCTIONS_TR = `Sen SatDedi'nin satış odaklı emlak asistanısın.
Kurallar:
- Sadece emlak/satış/kiralama/danışmanlık/iş ortaklığı bağlamında cevap ver.
- Emlak dışı isteklerde tek cümlede kibarca reddet ve emlak sürecine geri yönlendir.
- Asla rakamsal fiyat, değerleme, TL aralığı, m2 fiyatı verme.
- En fazla tek cümle yaz.
- Cevabın sonunda tek bir kısa sonraki adım sorusu sor.
- Ton kısa, net, ikna edici ve satışa yönlendirici olsun.
- Kullanıcıyı SatDedi'de süreci başlatmaya yönlendir.`;

type ChatPayload = {
  message?: unknown;
  history?: unknown;
  messages?: unknown;
};

type UpstreamMessage = { role: "user" | "assistant"; content: string };

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function parseGuestCount(req: NextRequest) {
  const raw = req.cookies.get(GUEST_COUNT_COOKIE)?.value;
  const parsed = Number(raw ?? 0);
  if (!Number.isFinite(parsed) || parsed < 0) return 0;
  return Math.floor(parsed);
}

function isAuthenticated(req: NextRequest) {
  return Boolean(
    req.cookies.get("token")?.value ||
      req.cookies.get("access_token")?.value ||
      req.cookies.get("auth_token")?.value,
  );
}

function cookieValue(nextCount: number) {
  return `${GUEST_COUNT_COOKIE}=${nextCount}; Path=/; Max-Age=86400; SameSite=Lax; HttpOnly`;
}

function extractMessages(payload: ChatPayload): UpstreamMessage[] {
  if (Array.isArray(payload.messages)) {
    return payload.messages
      .map((item) => {
        if (!item || typeof item !== "object") return null;
        const roleRaw = (item as { role?: unknown }).role;
        const contentRaw = (item as { content?: unknown }).content;
        if ((roleRaw !== "user" && roleRaw !== "assistant") || typeof contentRaw !== "string") return null;
        const content = contentRaw.trim();
        if (!content) return null;
        return { role: roleRaw, content } as UpstreamMessage;
      })
      .filter((item): item is UpstreamMessage => Boolean(item));
  }

  const historyMessages = Array.isArray(payload.history)
    ? payload.history
        .map((item) => {
          if (!item || typeof item !== "object") return null;
          const roleRaw = (item as { role?: unknown }).role;
          const contentRaw = (item as { content?: unknown }).content;
          if ((roleRaw !== "user" && roleRaw !== "assistant") || typeof contentRaw !== "string") return null;
          const content = contentRaw.trim();
          if (!content) return null;
          return { role: roleRaw, content } as UpstreamMessage;
        })
        .filter((item): item is UpstreamMessage => Boolean(item))
    : [];

  const message = typeof payload.message === "string" ? payload.message.trim() : "";
  if (message) {
    historyMessages.push({ role: "user", content: message });
  }

  return historyMessages;
}

function getLatestUserMessage(messages: UpstreamMessage[]) {
  for (let i = messages.length - 1; i >= 0; i -= 1) {
    if (messages[i].role === "user") return messages[i].content;
  }
  return "";
}

function isRealEstateTopic(text: string) {
  return /(ev|daire|arsa|tarla|emlak|sat|kirala|kiralık|satılık|mülk|danışman|iş ortağı|portföy|ilan|tapu|ofis|dükkan|konut|ticari|devir)/i.test(
    text,
  );
}

function normalizeSingleSentence(raw: string, userText: string) {
  const compact = raw.replace(/\s+/g, " ").trim();
  const firstSentence = compact.split(/(?<=[.!?])\s+/)[0]?.trim() || "";

  // Never allow numeric valuation style answers.
  const containsNumeric = /\d|₺|\bTL\b|\byüzde\b|\baralık\b/i.test(firstSentence);
  if (containsNumeric || /fiyat|değer|m2/i.test(userText)) {
    return "Net fiyat veremem; SatDedi'de ücretsiz analiz başlatalım, mülk türü ve konumu nedir?";
  }

  if (!isRealEstateTopic(userText)) {
    return "Bu konuda yardımcı olamam; emlak satışı veya kiralama için mülk türü ve konumu paylaşır mısın?";
  }

  if (!firstSentence) {
    return "SatDedi'de süreci hemen başlatabiliriz, mülk türü ve konumu nedir?";
  }

  if (/[?؟]$/.test(firstSentence)) return firstSentence;
  return `${firstSentence.replace(/[.!]+$/, "")}, mülk türü ve konumu nedir?`;
}

function chunkText(text: string) {
  const words = text.split(" ");
  const chunks: string[] = [];
  let current = "";

  for (const word of words) {
    const candidate = current ? `${current} ${word}` : word;
    if (candidate.length >= 14) {
      chunks.push(candidate);
      current = "";
    } else {
      current = candidate;
    }
  }

  if (current) chunks.push(current);
  return chunks;
}

async function fetchOpenAI(messages: UpstreamMessage[], signal: AbortSignal) {
  const apiKey = process.env.OPENAI_API_KEY?.trim();
  if (!apiKey) {
    throw new Error("OPENAI_API_KEY missing");
  }

  const model = process.env.OPENAI_CHAT_MODEL?.trim() || "gpt-5-mini";
  const promptId = process.env.OPENAI_PROMPT_ID?.trim();

  const body: Record<string, unknown> = {
    model,
    instructions: SALES_INSTRUCTIONS_TR,
    input: messages.slice(-10).map((m) => ({ role: m.role, content: m.content })),
    max_output_tokens: 80,
    reasoning: { effort: "minimal" },
  };

  if (promptId) {
    body.prompt = { id: promptId };
  }

  const upstream = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
    signal,
  });

  const responseText = await upstream.text();
  if (!upstream.ok) {
    console.error(`[api/public/chat] openai error status=${upstream.status} body=${responseText.slice(0, 500)}`);
    throw new Error("openai_upstream_error");
  }

  let parsed: unknown = null;
  try {
    parsed = JSON.parse(responseText);
  } catch {
    parsed = null;
  }

  if (!parsed || typeof parsed !== "object") return "";

  const topLevel = (parsed as { output_text?: unknown }).output_text;
  if (typeof topLevel === "string" && topLevel.trim()) return topLevel.trim();

  const output = (parsed as { output?: unknown }).output;
  if (!Array.isArray(output)) return "";

  const parts: string[] = [];
  for (const item of output) {
    if (!item || typeof item !== "object") continue;
    const content = (item as { content?: unknown }).content;
    if (!Array.isArray(content)) continue;

    for (const piece of content) {
      if (!piece || typeof piece !== "object") continue;
      const text = (piece as { text?: unknown }).text;
      if (typeof text === "string" && text.trim()) parts.push(text.trim());
    }
  }

  return parts.join(" ").trim();
}

export async function POST(req: NextRequest) {
  let payload: ChatPayload;
  try {
    payload = (await req.json()) as ChatPayload;
  } catch {
    return new Response(JSON.stringify({ message: "Invalid JSON payload" }), {
      status: 400,
      headers: { "content-type": "application/json; charset=utf-8" },
    });
  }

  const authenticated = isAuthenticated(req);
  const currentCount = parseGuestCount(req);

  if (!authenticated && currentCount >= MAX_GUEST_MESSAGES) {
    return new Response(JSON.stringify({ message: "Devam etmek için giriş yap.", code: "GUEST_LIMIT_REACHED" }), {
      status: 429,
      headers: {
        "content-type": "application/json; charset=utf-8",
        "x-guest-remaining": "0",
      },
    });
  }

  const messages = extractMessages(payload);
  const userText = getLatestUserMessage(messages);
  if (!userText) {
    return new Response(JSON.stringify({ message: "Mesaj bulunamadı" }), {
      status: 400,
      headers: { "content-type": "application/json; charset=utf-8" },
    });
  }

  const nextCount = authenticated ? currentCount : currentCount + 1;
  const remaining = authenticated ? 999 : Math.max(0, MAX_GUEST_MESSAGES - nextCount);

  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      const encoder = new TextEncoder();
      let closed = false;

      const write = (chunk: string) => {
        if (closed) return;
        controller.enqueue(encoder.encode(chunk));
      };

      const close = () => {
        if (closed) return;
        closed = true;
        controller.close();
      };

      const fail = (message: string) => {
        write(`event: error\ndata: ${JSON.stringify({ message })}\n\n`);
        write("event: done\ndata: {\"ok\":false}\n\n");
        close();
      };

      write("retry: 15000\n\n");
      write(`event: meta\ndata: ${JSON.stringify({ remaining })}\n\n`);

      const heartbeat = setInterval(() => {
        write(": heartbeat\n\n");
      }, 15000);

      const cleanup = () => {
        clearInterval(heartbeat);
        close();
      };

      req.signal.addEventListener("abort", cleanup, { once: true });

      (async () => {
        try {
          let responseText = "";

          if (!isRealEstateTopic(userText)) {
            responseText = "Bu konuda yardımcı olamam; emlak satışı veya kiralama için mülk türü ve konumu paylaşır mısın?";
          } else {
            write(`event: status\ndata: ${JSON.stringify({ text: "Düşünüyor..." })}\n\n`);
            const upstreamText = await fetchOpenAI(messages, req.signal);
            responseText = normalizeSingleSentence(upstreamText, userText);
          }

          const chunks = chunkText(responseText);
          for (const chunk of chunks) {
            if (req.signal.aborted) {
              cleanup();
              return;
            }
            write(`event: delta\ndata: ${JSON.stringify({ text: chunk + " " })}\n\n`);
            await delay(36);
          }

          write("event: done\ndata: {\"ok\":true}\n\n");
          cleanup();
        } catch (err) {
          if ((err as { name?: string })?.name === "AbortError") {
            cleanup();
            return;
          }
          console.error("[api/public/chat] failed", err);
          fail("Yanıt alınamadı. Lütfen tekrar dene.");
        }
      })();
    },
  });

  return new Response(stream, {
    status: 201,
    headers: {
      "content-type": "text/event-stream; charset=utf-8",
      "cache-control": "no-cache, no-transform",
      connection: "keep-alive",
      "x-accel-buffering": "no",
      "x-guest-remaining": String(remaining),
      ...(authenticated ? {} : { "set-cookie": cookieValue(nextCount) }),
    },
  });
}
