import React from "react";

type LogoSize = "sm" | "md" | "lg";

type LogoProps = {
  size?: LogoSize;
  className?: string;
};

const SIZE_CLASS: Record<LogoSize, string> = {
  sm: "text-lg",
  md: "text-xl",
  lg: "text-4xl md:text-5xl",
};

export default function Logo({ size = "md", className = "" }: LogoProps) {
  return (
    <span
      className={`font-montserrat tracking-tight ${SIZE_CLASS[size]} ${className}`.trim()}
      style={{ color: "var(--color-logo)" }}
    >
      <span className="font-black">Sat</span>
      <span className="font-light">Dedi</span>
    </span>
  );
}

