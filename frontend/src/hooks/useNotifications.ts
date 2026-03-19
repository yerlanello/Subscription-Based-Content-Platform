import { useEffect, useRef, useState, useCallback } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { getTokens } from "@/lib/auth";

export interface Notification {
  id: string;
  type: string;
  title: string;
  body?: string;
  link?: string;
  is_read: boolean;
  created_at: string;
}

export interface SSEEvent {
  id: string;
  type: string;
  title: string;
  body?: string;
  link?: string;
}

const BASE_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8080/api";

export function useSSENotifications(enabled: boolean) {
  const queryClient = useQueryClient();
  const [toasts, setToasts] = useState<SSEEvent[]>([]);
  const esRef = useRef<EventSource | null>(null);

  const dismissToast = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  useEffect(() => {
    if (!enabled) return;

    const { accessToken } = getTokens();
    if (!accessToken) return;

    // EventSource не поддерживает заголовки — передаём токен через query param
    const url = `${BASE_URL}/notifications/stream?token=${accessToken}`;
    const es = new EventSource(url);
    esRef.current = es;

    es.onmessage = (e) => {
      try {
        const event: SSEEvent = JSON.parse(e.data);
        // Добавляем toast
        setToasts((prev) => [event, ...prev].slice(0, 5));
        // Инвалидируем список уведомлений
        queryClient.invalidateQueries({ queryKey: ["notifications"] });
        // Автоудаление через 6 секунд
        setTimeout(() => dismissToast(event.id), 6000);
      } catch {
        // ignore parse errors
      }
    };

    es.onerror = () => {
      es.close();
    };

    return () => {
      es.close();
      esRef.current = null;
    };
  }, [enabled, queryClient, dismissToast]);

  return { toasts, dismissToast };
}
