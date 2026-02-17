import React from "react";

type SuggestionsOverlayProps = {
  text: string;
  cursorVisible: boolean;
  active: boolean;
};

export default function SuggestionsOverlay({ text, cursorVisible, active }: SuggestionsOverlayProps) {
  if (!active) return null;

  return (
    <div
      aria-hidden="true"
      className="pointer-events-none absolute inset-y-0 left-4 right-4 flex items-center overflow-hidden"
      style={{ color: "var(--color-text-muted)" }}
    >
      <span className="truncate text-sm">{text}</span>
      <span className="ml-0.5 text-sm">{cursorVisible ? "|" : " "}</span>
    </div>
  );
}

