"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { streamsApi } from "@/lib/api";
import dynamic from "next/dynamic";
import {
  LiveKitRoom,
  RoomAudioRenderer,
  VideoTrack,
  useTracks,
} from "@livekit/components-react";
import { Track } from "livekit-client";
import "@livekit/components-styles";
import { MapPin, Users, ArrowLeft } from "lucide-react";
import Link from "next/link";
import type { StreamInfo } from "@/components/StreamMap";
import { StreamChat } from "@/components/StreamChat";

const StreamMap = dynamic(() => import("@/components/StreamMap"), { ssr: false });

// Viewer-only video — no publishing controls
function StreamViewer() {
  // Subscribe to both camera and screen-share so viewers see whichever the
  // streamer is publishing (the go-live page lets them toggle screen share).
  const tracks = useTracks(
    [Track.Source.Camera, Track.Source.ScreenShare],
    { onlySubscribed: true },
  );
  const [connecting, setConnecting] = useState(true);

  // After 8 seconds assume we're connected and streamer just has no video yet
  useEffect(() => {
    const t = setTimeout(() => setConnecting(false), 8000);
    return () => clearTimeout(t);
  }, []);

  // Track arrived — stop showing spinner
  useEffect(() => {
    if (tracks.length > 0) setConnecting(false);
  }, [tracks.length]);

  return (
    <div className="relative h-full w-full bg-black">
      {tracks.map((trackRef) => (
        <VideoTrack
          key={trackRef.participant.sid + String(trackRef.source)}
          trackRef={trackRef}
          style={{ width: "100%", height: "100%", objectFit: "contain" }}
        />
      ))}
      <RoomAudioRenderer />
      {tracks.length === 0 && (
        <div className="absolute inset-0 flex flex-col items-center justify-center gap-3">
          {connecting ? (
            <>
              <div className="h-8 w-8 animate-spin rounded-full border-3 border-white/30 border-t-white" />
              <span className="text-white/50 text-sm">Подключение к трансляции…</span>
            </>
          ) : (
            <span className="text-white/40 text-sm">Видео недоступно</span>
          )}
        </div>
      )}
    </div>
  );
}

export default function StreamViewPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();

  const [token, setToken] = useState("");
  const [livekitUrl, setLivekitUrl] = useState("");
  const [stream, setStream] = useState<StreamInfo | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    streamsApi
      .join(id)
      .then((res) => {
        const d = res.data.data;
        setToken(d.token);
        setLivekitUrl(d.livekit_url);
        setStream(d.stream);
      })
      .catch(() => setError("Трансляция не найдена или уже завершена"));
  }, [id]);

  if (error) {
    return (
      <div className="flex min-h-[60vh] flex-col items-center justify-center gap-4">
        <p className="text-gray-500">{error}</p>
        <Link href="/streams" className="btn-outline">
          К трансляциям
        </Link>
      </div>
    );
  }

  if (!token) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <div className="h-10 w-10 animate-spin rounded-full border-4 border-brand-600 border-t-transparent" />
      </div>
    );
  }

  const mapStreams: StreamInfo[] = stream ? [stream] : [];

  return (
    <div className="mx-auto max-w-7xl px-4 py-6">
      {/* Header */}
      <div className="mb-4 flex items-center gap-3">
        <button onClick={() => router.back()} className="btn-ghost p-2">
          <ArrowLeft size={18} />
        </button>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <span className="flex items-center gap-1 rounded-full bg-red-500 px-2 py-0.5 text-xs font-semibold text-white">
              <span className="h-1.5 w-1.5 rounded-full bg-white animate-pulse" />
              LIVE
            </span>
            <h1 className="font-bold truncate">{stream?.title}</h1>
          </div>
          <div className="flex items-center gap-3 text-sm text-gray-500">
            <span>{stream?.display_name}</span>
            {stream?.viewer_count != null && (
              <span className="flex items-center gap-1">
                <Users size={13} />
                {stream.viewer_count}
              </span>
            )}
            {stream?.latitude && (
              <span className="flex items-center gap-1">
                <MapPin size={13} />
                Местоположение указано
              </span>
            )}
          </div>
        </div>
      </div>

      {/* LiveKitRoom wraps everything so chat shares the room context */}
      <LiveKitRoom
        token={token}
        serverUrl={livekitUrl}
        connect={true}
        video={false}
        audio={false}
        className="contents"
      >
        <div className="grid gap-4 lg:grid-cols-3" style={{ height: "calc(100vh - 200px)", minHeight: 500 }}>
          {/* Video — left 2/3 */}
          <div className="lg:col-span-2 flex flex-col gap-4">
            <div className="overflow-hidden rounded-xl bg-black flex-1">
              <StreamViewer />
            </div>

            {/* Author info (below video on desktop) */}
            <div className="card p-4 flex items-center gap-3">
              {stream?.avatar_url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={stream.avatar_url}
                  alt={stream.username}
                  className="h-10 w-10 rounded-full object-cover"
                />
              ) : (
                <div className="flex h-10 w-10 items-center justify-center rounded-full bg-brand-100 text-sm font-bold text-brand-600">
                  {stream?.display_name?.[0]?.toUpperCase()}
                </div>
              )}
              <div className="flex-1 min-w-0">
                <p className="font-semibold">{stream?.display_name}</p>
                <Link
                  href={`/creators/${stream?.username}`}
                  className="text-sm text-brand-600 hover:underline"
                >
                  @{stream?.username}
                </Link>
              </div>
              {stream?.latitude && (
                <div style={{ width: 160, height: 100, borderRadius: 8, overflow: "hidden" }}>
                  <StreamMap streams={mapStreams} />
                </div>
              )}
            </div>
          </div>

          {/* Chat — right 1/3 */}
          <div className="card p-0 overflow-hidden flex flex-col">
            <StreamChat streamId={id} />
          </div>
        </div>
      </LiveKitRoom>
    </div>
  );
}