"use client";

import { useEffect, useRef, useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { notificationsApi } from "@/lib/api";
import { Notification } from "@/hooks/useNotifications";
import { Bell, Trash2 } from "lucide-react";
import Link from "next/link";
import { formatDistanceToNow } from "date-fns";
import { ru } from "date-fns/locale";
import { usePathname } from "next/navigation";

interface NotifResponse {
  notifications: Notification[];
  unread_count: number;
}

export function NotificationBell() {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const pathname = usePathname();
  const queryClient = useQueryClient();

  useEffect(() => { setOpen(false); }, [pathname]);

  useEffect(() => {
    if (!open) return;
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, [open]);

  const { data } = useQuery<NotifResponse>({
    queryKey: ["notifications"],
    queryFn: () => notificationsApi.list().then((r) => r.data.data),
    refetchInterval: 30000,
  });

  const markAllMutation = useMutation({
    mutationFn: () => notificationsApi.markAllRead(),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["notifications"] }),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => notificationsApi.delete(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["notifications"] }),
  });

  const deleteAllMutation = useMutation({
    mutationFn: () => notificationsApi.deleteAll(),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["notifications"] }),
  });

  const unread = data?.unread_count ?? 0;
  const notifications = data?.notifications ?? [];

  const handleOpen = () => {
    setOpen((v) => !v);
    if (!open && unread > 0) {
      markAllMutation.mutate();
    }
  };

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={handleOpen}
        className="relative flex h-9 w-9 items-center justify-center rounded-full transition-colors hover:bg-gray-100"
        title="Уведомления"
      >
        <Bell size={18} className="text-gray-600" />
        {unread > 0 && (
          <span className="absolute -right-0.5 -top-0.5 flex h-4 w-4 items-center justify-center rounded-full bg-brand-600 text-[10px] font-bold text-white">
            {unread > 9 ? "9+" : unread}
          </span>
        )}
      </button>

      <div
        className={`absolute right-0 mt-2 w-80 origin-top-right transition-all duration-150 ${
          open ? "scale-100 opacity-100 pointer-events-auto" : "scale-95 opacity-0 pointer-events-none"
        }`}
      >
        <div className="card shadow-lg overflow-hidden">
          <div className="flex items-center justify-between border-b px-4 py-3">
            <h3 className="font-semibold text-sm">Уведомления</h3>
            <div className="flex items-center gap-3">
              {unread > 0 && (
                <button
                  onClick={() => markAllMutation.mutate()}
                  className="text-xs text-brand-600 hover:underline"
                >
                  Прочитать все
                </button>
              )}
              {notifications.length > 0 && (
                <button
                  onClick={() => deleteAllMutation.mutate()}
                  disabled={deleteAllMutation.isPending}
                  title="Удалить все"
                  className="text-gray-400 hover:text-red-500 transition-colors"
                >
                  <Trash2 size={14} />
                </button>
              )}
            </div>
          </div>

          <div className="max-h-96 overflow-y-auto divide-y">
            {notifications.length === 0 ? (
              <div className="px-4 py-8 text-center text-sm text-gray-400">
                Уведомлений пока нет
              </div>
            ) : (
              notifications.map((n) => (
                <div
                  key={n.id}
                  className={`flex items-start gap-2 px-4 py-3 text-sm transition-colors hover:bg-gray-50 ${
                    !n.is_read ? "bg-brand-50" : ""
                  }`}
                >
                  <Link
                    href={n.link ?? "/feed"}
                    onClick={() => setOpen(false)}
                    className="flex flex-1 gap-3 min-w-0"
                  >
                    <div className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-brand-100">
                      <Bell size={14} className="text-brand-600" />
                    </div>
                    <div className="min-w-0">
                      <p className="font-medium leading-tight">{n.title}</p>
                      {n.body && (
                        <p className="mt-0.5 truncate text-gray-500">{n.body}</p>
                      )}
                      <p className="mt-1 text-xs text-gray-400">
                        {formatDistanceToNow(new Date(n.created_at), {
                          addSuffix: true,
                          locale: ru,
                        })}
                      </p>
                    </div>
                    {!n.is_read && (
                      <div className="mt-2 h-2 w-2 shrink-0 rounded-full bg-brand-600" />
                    )}
                  </Link>
                  <button
                    onClick={() => deleteMutation.mutate(n.id)}
                    title="Удалить"
                    className="mt-1 shrink-0 text-gray-300 hover:text-red-500 transition-colors"
                  >
                    <Trash2 size={13} />
                  </button>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
