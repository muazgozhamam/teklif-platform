import { useEffect } from "react";
import type { RefObject } from "react";

type Options = {
  ref: RefObject<HTMLTextAreaElement | null>;
  value: string;
  maxHeight?: number;
};

export function useAutosizeTextarea({ ref, value, maxHeight = 180 }: Options) {
  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    el.style.height = "0px";
    const nextHeight = Math.min(el.scrollHeight, maxHeight);
    el.style.height = `${nextHeight}px`;
    el.style.overflowY = el.scrollHeight > maxHeight ? "auto" : "hidden";
  }, [maxHeight, ref, value]);
}
