import React from "react";

export default function ActionChips() {
  return (
    <div className="mt-3 flex items-center justify-center gap-2">
      <a
        href="/danisman-ol"
        className="inline-flex items-center justify-center rounded-full border px-3 py-1.5 text-xs transition hover:opacity-90"
        style={{ borderColor: "var(--color-border)", color: "var(--color-text-secondary)", background: "var(--color-surface)" }}
      >
        Danışman ol
      </a>
      <a
        href="/is-ortagi-ol"
        className="inline-flex items-center justify-center rounded-full border px-3 py-1.5 text-xs transition hover:opacity-90"
        style={{ borderColor: "var(--color-border)", color: "var(--color-text-secondary)", background: "var(--color-surface)" }}
      >
        İş ortağı ol
      </a>
    </div>
  );
}
