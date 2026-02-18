"use client";

import React from "react";
import Modal from "@/components/ui/Modal";

type ModalShellProps = {
  open: boolean;
  title: string;
  onClose: () => void;
  children: React.ReactNode;
  maxWidthClass?: string;
};

export default function ModalShell({
  open,
  title,
  onClose,
  children,
  maxWidthClass = "max-w-md",
}: ModalShellProps) {
  return (
    <Modal isOpen={open} onClose={onClose} title={title} maxWidthClass={maxWidthClass}>
      {children}
    </Modal>
  );
}
