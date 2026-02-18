import React from 'react';

type ClampSize = 'hero' | 'input' | 'cards' | 'base';

const SIZE_CLASS: Record<ClampSize, string> = {
  hero: 'max-w-[900px]',
  input: 'max-w-[900px]',
  cards: 'max-w-[1120px]',
  base: 'max-w-[1120px]',
};

export default function ContentClamp({ size = 'base', className = '', children }: { size?: ClampSize; className?: string; children: React.ReactNode }) {
  return <div className={`mx-auto w-full ${SIZE_CLASS[size]} ${className}`.trim()}>{children}</div>;
}
