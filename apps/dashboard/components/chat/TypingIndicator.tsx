import React from "react";

export default function TypingIndicator() {
  return (
    <div className="flex w-full justify-start">
      <div className="max-w-[88%] rounded-3xl px-4 py-3 text-[15px]" style={{ color: "var(--color-text-muted)" }}>
        <div className="typing-shimmer flex items-center gap-2 rounded-xl px-2 py-1">
          <span className="typing-dots" aria-hidden="true">
            <span className="typing-dot" />
            <span className="typing-dot" />
            <span className="typing-dot" />
          </span>
          <span className="text-sm">Düşünüyor...</span>
        </div>
      </div>
    </div>
  );
}

