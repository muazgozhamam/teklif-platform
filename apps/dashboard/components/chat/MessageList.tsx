import React from "react";
import type { RefObject } from "react";
import TypingIndicator from "./TypingIndicator";

type Role = "assistant" | "user" | "system";
type Message = { id: string; role: Role; text: string };

type MessageListProps = {
  messages: Message[];
  isStreaming: boolean;
  lastError: string | null;
  containerRef: RefObject<HTMLDivElement | null>;
  onScroll: () => void;
};

export default function MessageList({
  messages,
  isStreaming,
  lastError,
  containerRef,
  onScroll,
}: MessageListProps) {
  return (
    <section
      ref={containerRef}
      onScroll={onScroll}
      className="mx-auto flex w-full max-w-3xl flex-1 flex-col gap-6 overflow-y-auto pb-40 pt-6"
    >
      {messages.map((m) => (
        <div key={m.id} className={`flex w-full ${m.role === "user" ? "justify-end" : "justify-start"}`}>
          <div
            className={["max-w-[88%] whitespace-pre-wrap rounded-3xl px-4 py-3 text-[15px] leading-7", m.role === "user" ? "text-white" : ""].join(" ")}
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

      {isStreaming ? <TypingIndicator /> : null}

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
  );
}
