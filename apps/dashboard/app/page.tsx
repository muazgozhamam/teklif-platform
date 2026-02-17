"use client";

import React, { useMemo, useRef, useState } from "react";
import LandingShell from "@/components/landing/LandingShell";
import PromptBar from "@/components/landing/PromptBar";
import SuggestionCard from "@/components/landing/SuggestionCard";
import LandingHeader from "@/components/landing/LandingHeader";

type Role = "assistant" | "user" | "system";
type Message = { id: string; role: Role; text: string };

function resolvePublicApiBase() {
  const envBase = process.env.NEXT_PUBLIC_API_BASE_URL?.trim();
  if (envBase) return envBase.replace(/\/+$/, "");

  if (typeof window === "undefined") return "";
  const host = window.location.hostname;
  if (host === "stage.satdedi.com") return "https://api-stage-44dd.up.railway.app";
  if (host === "app.satdedi.com") return "https://api.satdedi.com";
  return "";
}

export default function PublicChatPage() {
  const [messages, setMessages] = useState<Message[]>([
    {
      id: "welcome",
      role: "assistant",
      text: "Merhaba, ben SatDedi Asistanı. Emlakla ilgili sorunu yaz, birlikte netleştirelim.",
    },
  ]);
  const [input, setInput] = useState("");
  const [isStreaming, setIsStreaming] = useState(false);
  const [lastError, setLastError] = useState<string | null>(null);
  const [showSuggestionCard, setShowSuggestionCard] = useState(true);
  const [hasInteracted, setHasInteracted] = useState(false);
  const [hasStartedChat, setHasStartedChat] = useState(false);

  const listRef = useRef<HTMLDivElement | null>(null);
  const composerRef = useRef<HTMLTextAreaElement | HTMLInputElement | null>(null);
  const shouldStickToBottomRef = useRef(true);

  const placeholder = useMemo(() => "", []);
  const exampleText = useMemo(
    () => "Danışman olmak istiyorum.",
    [],
  );
  const isCenteredComposer = !hasInteracted && !hasStartedChat && messages.length <= 1;
  const showExampleAsValue = !hasStartedChat && !hasInteracted && input.trim().length === 0;

  function addMessage(role: Role, text: string) {
    const id = `m_${Date.now()}_${Math.random().toString(16).slice(2)}`;
    setMessages((prev) => [...prev, { id, role, text }]);
    return id;
  }

  function setAssistantText(messageId: string, text: string) {
    setMessages((prev) =>
      prev.map((m) => (m.id === messageId ? { ...m, text } : m)),
    );
  }

  function appendAssistantText(messageId: string, deltaText: string) {
    setMessages((prev) =>
      prev.map((m) => (m.id === messageId ? { ...m, text: `${m.text}${deltaText}` } : m)),
    );
  }

  function handleComposerInteract() {
    setHasInteracted(true);
    setShowSuggestionCard(false);
  }

  function updateScrollStickiness() {
    const el = listRef.current;
    if (!el) return;
    const threshold = 80;
    const distanceToBottom = el.scrollHeight - el.scrollTop - el.clientHeight;
    shouldStickToBottomRef.current = distanceToBottom <= threshold;
  }

  function scrollToBottomIfNeeded() {
    if (!shouldStickToBottomRef.current) return;
    const el = listRef.current;
    if (!el) return;
    requestAnimationFrame(() => {
      el.scrollTop = el.scrollHeight;
    });
  }

  async function onSend() {
    const text = input.trim();
    if (!text || isStreaming) return;

    const history = messages
      .filter((m) => (m.role === "assistant" || m.role === "user") && m.text.trim().length > 0)
      .slice(-12)
      .map((m) => ({ role: m.role, content: m.text }));

    setInput("");
    setLastError(null);
    setHasInteracted(true);
    setHasStartedChat(true);
    setShowSuggestionCard(false);
    shouldStickToBottomRef.current = true;

    addMessage("user", text);
    const assistantId = addMessage("assistant", "");
    setIsStreaming(true);
    scrollToBottomIfNeeded();

    try {
      const apiBase = resolvePublicApiBase();
      const endpoint = apiBase ? `${apiBase}/public/chat/stream` : "/api/public/chat";

      const res = await fetch(endpoint, {
        method: "POST",
        headers: {
          Accept: "text/event-stream, application/json",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ message: text, history }),
      });

      if (!res.ok) {
        const bodyText = await res.text().catch(() => "");
        throw new Error(`Chat failed: ${res.status} ${bodyText}`);
      }

      const contentType = (res.headers.get("content-type") || "").toLowerCase();

      if (!contentType.includes("text/event-stream")) {
        const payload = (await res.json()) as { text?: string };
        const reply = (payload?.text || "").trim();
        if (!reply) {
          setAssistantText(assistantId, "Şu an yanıt üretemedim. Lütfen tekrar sorar mısın?");
          setLastError("Yanıt üretilemedi.");
          return;
        }
        setAssistantText(assistantId, reply);
        setLastError(null);
        return;
      }

      const reader = res.body?.getReader();
      if (!reader) {
        throw new Error("No response stream");
      }

      const decoder = new TextDecoder();
      let buffer = "";
      let sawDelta = false;

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const blocks = buffer.split("\n\n");
        buffer = blocks.pop() ?? "";

        for (const rawBlock of blocks) {
          const block = rawBlock.trim();
          if (!block) continue;

          const lines = block.split("\n");
          let eventName = "message";
          const dataLines: string[] = [];

          for (const line of lines) {
            if (line.startsWith(":")) continue;
            if (line.startsWith("event:")) {
              eventName = line.slice(6).trim();
              continue;
            }
            if (line.startsWith("data:")) {
              dataLines.push(line.slice(5).trim());
            }
          }

          if (!dataLines.length) continue;
          const dataText = dataLines.join("\n");

          let payload: { text?: string; message?: string; ok?: boolean } | null = null;
          try {
            payload = JSON.parse(dataText);
          } catch {
            payload = null;
          }

          if (eventName === "delta" && payload?.text) {
            sawDelta = true;
            appendAssistantText(assistantId, payload.text);
            scrollToBottomIfNeeded();
            continue;
          }

          if (eventName === "error") {
            setLastError(payload?.message || "Bağlantı koptu. Lütfen tekrar dene.");
          }
        }
      }

      if (!sawDelta) {
        setAssistantText(assistantId, "Şu an yanıt üretemedim. Lütfen tekrar sorar mısın?");
        setLastError("Yanıt üretilemedi.");
      } else {
        setLastError(null);
      }
    } catch (err) {
      console.error("[chat-ui] stream failed", err);
      setAssistantText(assistantId, "Şu an yanıt üretemedim. Lütfen tekrar sorar mısın?");
      setLastError("Bağlantı koptu. Lütfen tekrar dene.");
    } finally {
      setIsStreaming(false);
      scrollToBottomIfNeeded();
    }
  }

  return (
    <LandingShell footer="SatDedi Asistanı size destek olur; önemli kararlar öncesinde teyit etmenizi öneririz.">
      <LandingHeader />

      {isCenteredComposer ? (
        <section className="flex flex-1 flex-col items-center justify-center">
          <h1 className="mb-6 text-center text-3xl font-semibold tracking-tight md:text-5xl">
            Nasıl yardımcı olabilirim?
          </h1>

          <div className="w-full">
            <PromptBar
              phase="collect_intent"
              input={input}
              disabled={isStreaming}
              placeholder={placeholder}
              exampleText={exampleText}
              showExampleAsValue={showExampleAsValue}
              onSend={onSend}
              onInputChange={(value) => setInput(value)}
              isPhoneValid
              inputRef={composerRef}
              onInteract={handleComposerInteract}
            />

            {showSuggestionCard ? (
              <SuggestionCard onTryNow={() => composerRef.current?.focus()} onClose={() => setShowSuggestionCard(false)} />
            ) : null}
          </div>
        </section>
      ) : (
        <>
          <section
            ref={listRef}
            onScroll={updateScrollStickiness}
            className="mx-auto flex w-full max-w-3xl flex-1 flex-col gap-6 overflow-y-auto pb-40 pt-6"
          >
            {messages.map((m) => (
              <div key={m.id} className={`flex w-full ${m.role === "user" ? "justify-end" : "justify-start"}`}>
                <div
                  className={[
                    "max-w-[88%] whitespace-pre-wrap rounded-3xl px-4 py-3 text-[15px] leading-7",
                    m.role === "user" ? "text-white" : "",
                  ].join(" ")}
                  style={
                    m.role === "user"
                      ? { background: "#2f2f2f" }
                      : m.role === "system"
                        ? {
                            background: "rgba(220,38,38,0.08)",
                            border: "1px solid rgba(220,38,38,0.25)",
                            color: "var(--color-danger-600)",
                          }
                        : { color: "var(--color-text-primary)" }
                  }
                >
                  {m.text}
                </div>
              </div>
            ))}

            {isStreaming ? (
              <div className="flex w-full justify-start">
                <div
                  className="max-w-[88%] rounded-3xl px-4 py-3 text-[15px]"
                  style={{ color: "var(--color-text-muted)" }}
                >
                  <div className="flex items-center gap-2">
                    <span className="typing-dots" aria-hidden="true">
                      <span className="typing-dot" />
                      <span className="typing-dot" />
                      <span className="typing-dot" />
                    </span>
                    <span className="text-sm">Yanıt yazıyor...</span>
                  </div>
                </div>
              </div>
            ) : null}

            {lastError ? (
              <div
                className="mx-auto w-full max-w-2xl rounded-2xl border px-4 py-3 text-xs"
                style={{
                  borderColor: "rgba(220,38,38,0.3)",
                  background: "rgba(220,38,38,0.08)",
                  color: "var(--color-danger-600)",
                }}
              >
                {lastError}
              </div>
            ) : null}
          </section>

          <div className="fixed bottom-0 left-0 right-0 z-20 px-3 pb-4 pt-2 md:px-6">
            <div className="mx-auto w-full max-w-3xl">
              <PromptBar
                phase="collect_intent"
                input={input}
                disabled={isStreaming}
                placeholder={placeholder}
                exampleText={exampleText}
                showExampleAsValue={showExampleAsValue}
                onSend={onSend}
                onInputChange={(value) => setInput(value)}
                isPhoneValid
                inputRef={composerRef}
                onInteract={handleComposerInteract}
              />
            </div>
          </div>
        </>
      )}
    </LandingShell>
  );
}
