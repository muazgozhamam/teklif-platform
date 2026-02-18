import React from "react";

export type JoinOption = "RESIDENTIAL" | "COMMERCIAL" | "CONSULTANT" | "PARTNER";

type StyleCarouselProps = {
  onSelect: (option: JoinOption) => void;
};

const OPTIONS: Array<{ title: string; subtitle: string; key: JoinOption }> = [
  {
    title: "Konut Sahibi",
    subtitle: "Evimi satmak/kiralamak istiyorum",
    key: "RESIDENTIAL",
  },
  {
    title: "Ticari Mülk",
    subtitle: "Ünitemi değerlendirmek istiyorum",
    key: "COMMERCIAL",
  },
  {
    title: "Danışman",
    subtitle: "Portföy al, teklif üret",
    key: "CONSULTANT",
  },
  {
    title: "İş Ortağı",
    subtitle: "Talep bul, süreci başlat",
    key: "PARTNER",
  },
];

export default function StyleCarousel({ onSelect }: StyleCarouselProps) {
  return (
    <div className="grid grid-cols-2 gap-2">
      {OPTIONS.map((item) => (
        <button
          key={item.title}
          type="button"
          onClick={() => onSelect(item.key)}
          aria-label={`${item.title} olarak devam et`}
          className="rounded-2xl border p-2 text-left text-xs transition-transform hover:scale-[1.02] focus:outline-none focus:ring-0 focus-visible:ring-0"
          style={{
            borderColor: "var(--color-border)",
            background: "var(--color-surface)",
            color: "var(--color-text-secondary)",
            boxShadow: "var(--shadow-sm)",
            WebkitTapHighlightColor: "transparent",
          }}
        >
          <div className="font-medium" style={{ color: "var(--color-text-primary)" }}>
            {item.title}
          </div>
          <div className="mt-1">{item.subtitle}</div>
        </button>
      ))}
    </div>
  );
}
