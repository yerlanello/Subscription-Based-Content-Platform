"use client";

import { SSEEvent } from "@/hooks/useNotifications";
import { X, Bell } from "lucide-react";
import Link from "next/link";

interface Props {
  toasts: SSEEvent[];
  onDismiss: (id: string) => void;
}

export function NotificationToasts({ toasts, onDismiss }: Props) {
  if (toasts.length === 0) return null;

  return (
    <div className="fixed bottom-4 right-4 z-[100] flex flex-col gap-2">
      {toasts.map((toast) => (
        <div
          key={toast.id}
          className="animate-fade-in flex w-80 items-start gap-3 rounded-xl border border-gray-200 bg-white p-4 shadow-lg"
        >
          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-brand-100">
            <Bell size={14} className="text-brand-600" />
          </div>
          <div className="min-w-0 flex-1">
            <p className="text-sm font-medium leading-tight">{toast.title}</p>
            {toast.body && (
              <p className="mt-0.5 truncate text-xs text-gray-500">{toast.body}</p>
            )}
            {toast.link && (
              <Link
                href={toast.link}
                className="mt-1 inline-block text-xs text-brand-600 hover:underline"
                onClick={() => onDismiss(toast.id)}
              >
                Открыть →
              </Link>
            )}
          </div>
          <button
            onClick={() => onDismiss(toast.id)}
            className="shrink-0 text-gray-400 hover:text-gray-600"
          >
            <X size={14} />
          </button>
        </div>
      ))}
    </div>
  );
}
