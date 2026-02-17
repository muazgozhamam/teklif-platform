import React from "react";

type ScrollToBottomButtonProps = {
  visible: boolean;
  count?: number;
  onClick: () => void;
};

export default function ScrollToBottomButton({ visible, count = 0, onClick }: ScrollToBottomButtonProps) {
  if (!visible) return null;

  return (
    <button
      type="button"
      onClick={onClick}
      aria-label="En alta git"
      className="fixed bottom-28 right-4 z-30 rounded-full border px-3 py-2 text-sm shadow-md md:right-6"
      style={{
        borderColor: "var(--color-border)",
        background: "var(--color-surface)",
        color: "var(--color-text-primary)",
      }}
    >
      <span className="inline-flex items-center gap-2">
        <span aria-hidden="true">↓</span>
        {count > 0 ? <span className="rounded-full px-2 py-0.5 text-xs" style={{ background: "var(--color-bg)" }}>{count}</span> : null}
      </span>
    </button>
  );
}

