import React from 'react';

type CenterColumnProps = {
  children: React.ReactNode;
  className?: string;
};

export default function CenterColumn({ children, className = '' }: CenterColumnProps) {
  return <div className={`mx-auto w-full max-w-[900px] px-6 md:px-8 ${className}`.trim()}>{children}</div>;
}
