"use client";

import { useQuery } from "@tanstack/react-query";
import { streamsApi } from "@/lib/api";
import dynamic from "next/dynamic";
import Link from "next/link";
import { Radio } from "lucide-react";
import type { StreamInfo } from "@/components/StreamMap";
import { useAuth } from "@/hooks/useAuth";

// Leaflet must be loaded client-side only
const StreamMap = dynamic(() => import("@/components/StreamMap"), {
  ssr: false,
  loading: () => (
    <div className="h-full w-full flex items-center justify-center bg-gray-100 dark:bg-gray-800 rounded-xl">
      <div className="h-8 w-8 animate-spin rounded-full border-4 border-brand-600 border-t-transparent" />
    </div>
  ),
});

function pluralStreams(n: number) {
  if (n % 10 === 1 && n % 100 !== 11) return `${n} активный эфир`;
  if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return `${n} активных эфира`;
  return `${n} активных эфиров`;
}

export default function StreamsPage() {
  const { user } = useAuth();
  const { data, isLoading } = useQuery({
    queryKey: ["streams"],
    queryFn: () => streamsApi.list().then((r) => r.data.data as StreamInfo[]),
    refetchInterval: 5000,
  });

  const streams = data ?? [];
  const liveStreams = streams.filter((s) => s.latitude != null && s.longitude != null);
  const noLocationStreams = streams.filter((s) => s.latitude == null || s.longitude == null);

  return (
    <div className="mx-auto max-w-6xl px-4 py-6">
      <div className="mb-6 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="flex h-9 w-9 items-center justify-center rounded-full bg-red-100 dark:bg-red-900/30">
            <Radio size={18} className="text-red-600" />
          </div>
          <div>
            <h1 className="text-xl font-bold">Прямые эфиры</h1>
            <p className="text-sm text-gray-500">
              {isLoading ? "Загрузка…" : pluralStreams(streams.length)}
            </p>
          </div>
        </div>
        {user && (
          <Link
            href="/streams/go-live"
            className="flex items-center gap-2 rounded-xl bg-red-500 px-4 py-2 text-sm font-semibold text-white hover:bg-red-600 transition-colors"
          >
            <Radio size={15} />
            Начать эфир
          </Link>
        )}
      </div>

      {/* Map */}
      <div className="mb-6 h-[420px] overflow-hidden rounded-xl border border-gray-200 dark:border-gray-700 shadow-sm">
        {!isLoading && <StreamMap streams={liveStreams} />}
      </div>

      {/* Stream list */}
      {streams.length === 0 && !isLoading && (
        <div className="py-16 text-center text-gray-400">
          <Radio size={40} className="mx-auto mb-3 opacity-30" />
          <p>Сейчас нет активных трансляций</p>
        </div>
      )}

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {streams.map((stream) => (
          <Link
            key={stream.id}
            href={`/streams/${stream.id}`}
            className="card p-4 hover:shadow-md transition-shadow group"
          >
            <div className="mb-3 flex items-center gap-3">
              {stream.avatar_url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={stream.avatar_url}
                  alt={stream.username}
                  className="h-10 w-10 rounded-full object-cover"
                />
              ) : (
                <div className="flex h-10 w-10 items-center justify-center rounded-full bg-brand-100 text-sm font-bold text-brand-600">
                  {stream.display_name?.[0]?.toUpperCase()}
                </div>
              )}
              <div className="min-w-0">
                <p className="font-semibold truncate">{stream.display_name}</p>
                <p className="text-xs text-gray-400">@{stream.username}</p>
              </div>
              <span className="ml-auto flex items-center gap-1 rounded-full bg-red-500 px-2 py-0.5 text-xs font-semibold text-white">
                <span className="h-1.5 w-1.5 rounded-full bg-white animate-pulse" />
                LIVE
              </span>
            </div>
            <p className="text-sm font-medium truncate group-hover:text-brand-600 transition-colors">
              {stream.title}
            </p>
            {noLocationStreams.includes(stream) && (
              <p className="mt-1 text-xs text-gray-400">Местоположение не указано</p>
            )}
          </Link>
        ))}
      </div>
    </div>
  );
}
