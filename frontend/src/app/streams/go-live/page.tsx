"use client";

import { useState, useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import { useQueryClient } from "@tanstack/react-query";
import { streamsApi } from "@/lib/api";
import { LiveKitRoom, useLocalParticipant } from "@livekit/components-react";
import { Track } from "livekit-client";
import {
  MapPin, Radio, StopCircle,
  Mic, MicOff, Video, VideoOff, Monitor, MonitorOff,
} from "lucide-react";
import { StreamChat } from "@/components/StreamChat";

const SESSION_KEY = "xabarla_live_session";

// Attaches LOCAL participant's track directly to a <video> element.
// Uses explicit event parameters so screen-share switchover is reliable.
function LocalVideoPreview() {
  const videoRef = useRef<HTMLVideoElement>(null);
  const { localParticipant } = useLocalParticipant();

  useEffect(() => {
    if (!localParticipant) return;

    const attachBest = () => {
      const vid = videoRef.current;
      if (!vid) return;
      const screenPub = localParticipant.getTrackPublication(Track.Source.ScreenShare);
      const cameraPub = localParticipant.getTrackPublication(Track.Source.Camera);
      const pub = screenPub?.track ? screenPub : cameraPub;
      if (pub?.track) {
        vid.srcObject = null; // detach previous
        pub.track.attach(vid);
      }
    };

    const onPublished = () => attachBest();
    const onUnpublished = () => {
      // Small delay so the unpublished track is actually gone before we query
      setTimeout(attachBest, 100);
    };

    attachBest();
    localParticipant.on("localTrackPublished", onPublished);
    localParticipant.on("localTrackUnpublished", onUnpublished);

    return () => {
      localParticipant.off("localTrackPublished", onPublished);
      localParticipant.off("localTrackUnpublished", onUnpublished);
    };
  }, [localParticipant]);

  return (
    <video
      ref={videoRef}
      autoPlay
      muted
      playsInline
      style={{ width: "100%", height: "100%", objectFit: "cover" }}
    />
  );
}

function StreamerRoom({
  title,
  streamId,
  locationEnabled,
  onEnd,
}: {
  title: string;
  streamId: string;
  locationEnabled: boolean;
  onEnd: () => void;
}) {
  const {
    localParticipant,
    isMicrophoneEnabled,
    isCameraEnabled,
    isScreenShareEnabled,
  } = useLocalParticipant();

  const toggleMic = () => localParticipant.setMicrophoneEnabled(!isMicrophoneEnabled);
  const toggleCamera = () => localParticipant.setCameraEnabled(!isCameraEnabled);
  const toggleScreen = () => localParticipant.setScreenShareEnabled(!isScreenShareEnabled);

  return (
    <div
      className="grid gap-4 lg:grid-cols-3"
      style={{ height: "calc(100vh - 80px)", minHeight: 520 }}
    >
      {/* Left: video + controls */}
      <div className="lg:col-span-2 flex flex-col gap-3 min-h-0">
        {/* Header */}
        <div className="flex flex-shrink-0 items-center justify-between">
          <div className="flex min-w-0 items-center gap-3">
            <span className="flex flex-shrink-0 items-center gap-1.5 rounded-full bg-red-500 px-3 py-1 text-sm font-semibold text-white">
              <span className="h-2 w-2 animate-pulse rounded-full bg-white" />
              В ЭФИРЕ
            </span>
            <span className="truncate font-semibold">{title}</span>
            {locationEnabled && (
              <span className="flex flex-shrink-0 items-center gap-1 text-xs text-green-600">
                <MapPin size={12} />
                Геолокация активна
              </span>
            )}
          </div>
          <button
            onClick={onEnd}
            className="ml-3 flex flex-shrink-0 items-center gap-2 rounded-xl bg-red-500 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-red-600"
          >
            <StopCircle size={16} />
            Завершить эфир
          </button>
        </div>

        {/* Video — only local */}
        <div className="relative min-h-0 flex-1 overflow-hidden rounded-xl bg-black">
          <LocalVideoPreview />
        </div>

        {/* Controls */}
        <div className="card flex flex-shrink-0 items-center justify-center gap-2 p-3">
          <button
            onClick={toggleMic}
            className={`flex items-center gap-2 rounded-xl px-4 py-2 text-sm font-medium transition-colors ${
              isMicrophoneEnabled
                ? "bg-gray-100 hover:bg-gray-200 dark:bg-gray-800 dark:hover:bg-gray-700"
                : "bg-red-100 text-red-600 hover:bg-red-200 dark:bg-red-900/30"
            }`}
          >
            {isMicrophoneEnabled ? <Mic size={16} /> : <MicOff size={16} />}
            {isMicrophoneEnabled ? "Микрофон" : "Выкл"}
          </button>

          <button
            onClick={toggleCamera}
            className={`flex items-center gap-2 rounded-xl px-4 py-2 text-sm font-medium transition-colors ${
              isCameraEnabled
                ? "bg-gray-100 hover:bg-gray-200 dark:bg-gray-800 dark:hover:bg-gray-700"
                : "bg-red-100 text-red-600 hover:bg-red-200 dark:bg-red-900/30"
            }`}
          >
            {isCameraEnabled ? <Video size={16} /> : <VideoOff size={16} />}
            {isCameraEnabled ? "Камера" : "Выкл"}
          </button>

          <button
            onClick={toggleScreen}
            className={`flex items-center gap-2 rounded-xl px-4 py-2 text-sm font-medium transition-colors ${
              isScreenShareEnabled
                ? "bg-brand-100 text-brand-600 hover:bg-brand-200 dark:bg-brand-900/30"
                : "bg-gray-100 hover:bg-gray-200 dark:bg-gray-800 dark:hover:bg-gray-700"
            }`}
          >
            {isScreenShareEnabled ? <MonitorOff size={16} /> : <Monitor size={16} />}
            {isScreenShareEnabled ? "Остановить" : "Экран"}
          </button>
        </div>
      </div>

      {/* Right: chat */}
      <div className="card flex min-h-0 flex-col overflow-hidden p-0">
        <StreamChat streamId={streamId} />
      </div>
    </div>
  );
}

export default function GoLivePage() {
  const router = useRouter();
  const queryClient = useQueryClient();

  const [initializing, setInitializing] = useState(true);
  const [title, setTitle] = useState("");
  const [step, setStep] = useState<"setup" | "live">("setup");
  const [token, setToken] = useState("");
  const [livekitUrl, setLivekitUrl] = useState("");
  const [streamId, setStreamId] = useState("");
  const [shareLocation, setShareLocation] = useState(false);
  const [locationEnabled, setLocationEnabled] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const watchIdRef = useRef<number | null>(null);

  // On load: try to restore active session from server
  useEffect(() => {
    streamsApi
      .getMine()
      .then((res) => {
        const d = res.data.data;
        if (d?.stream && d?.token) {
          setToken(d.token);
          setLivekitUrl(d.livekit_url);
          setStreamId(d.stream.id);
          setTitle(d.stream.title);
          // Restore shareLocation from sessionStorage if available
          try {
            const cached = sessionStorage.getItem(SESSION_KEY);
            if (cached) {
              const parsed = JSON.parse(cached);
              setShareLocation(parsed.shareLocation ?? false);
            }
          } catch { /* ignore */ }
          setStep("live");
          sessionStorage.setItem(
            SESSION_KEY,
            JSON.stringify({ streamId: d.stream.id, title: d.stream.title, shareLocation })
          );
        } else {
          // No active stream — clear any stale session
          sessionStorage.removeItem(SESSION_KEY);
        }
      })
      .catch(() => sessionStorage.removeItem(SESSION_KEY))
      .finally(() => setInitializing(false));
  }, []);

  // Watch geolocation while live (only if author opted in)
  useEffect(() => {
    if (step !== "live" || !streamId || !shareLocation || !navigator.geolocation) return;

    watchIdRef.current = navigator.geolocation.watchPosition(
      (pos) => {
        streamsApi.updateLocation(streamId, pos.coords.latitude, pos.coords.longitude);
        setLocationEnabled(true);
      },
      () => setLocationEnabled(false),
      { enableHighAccuracy: true, maximumAge: 10000 }
    );

    return () => {
      if (watchIdRef.current !== null) {
        navigator.geolocation.clearWatch(watchIdRef.current);
        watchIdRef.current = null;
      }
    };
  }, [step, streamId, shareLocation]);

  const startStream = async () => {
    if (!title.trim()) { setError("Введите название эфира"); return; }
    setLoading(true);
    setError("");
    try {
      const res = await streamsApi.start(title);
      const d = res.data.data;
      setToken(d.token);
      setLivekitUrl(d.livekit_url);
      setStreamId(d.stream.id);
      setStep("live");
      sessionStorage.setItem(
        SESSION_KEY,
        JSON.stringify({ streamId: d.stream.id, title, shareLocation })
      );
      queryClient.invalidateQueries({ queryKey: ["streams"] });
    } catch {
      setError("Не удалось запустить трансляцию");
    } finally {
      setLoading(false);
    }
  };

  const endStream = async () => {
    if (watchIdRef.current !== null) {
      navigator.geolocation.clearWatch(watchIdRef.current);
      watchIdRef.current = null;
    }
    sessionStorage.removeItem(SESSION_KEY);
    await streamsApi.end(streamId).catch(() => {});
    await queryClient.invalidateQueries({ queryKey: ["streams"] });
    router.push("/streams");
  };

  if (initializing) {
    return (
      <div className="flex min-h-[70vh] items-center justify-center">
        <div className="h-10 w-10 animate-spin rounded-full border-4 border-brand-600 border-t-transparent" />
      </div>
    );
  }

  if (step === "setup") {
    return (
      <div className="flex min-h-[70vh] items-center justify-center px-4">
        <div className="card w-full max-w-md p-8">
          <div className="mb-6 flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-red-100 dark:bg-red-900/30">
              <Radio size={20} className="text-red-600" />
            </div>
            <h1 className="text-xl font-bold">Начать прямой эфир</h1>
          </div>
          <div className="space-y-4">
            <div>
              <label className="mb-1 block text-sm font-medium">Название эфира</label>
              <input
                className="input"
                placeholder="Например: Стрим из кафе в центре города"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && startStream()}
                autoFocus
              />
            </div>
            <label className="flex cursor-pointer items-center justify-between rounded-lg border border-gray-200 px-4 py-3 transition-colors hover:bg-gray-50 dark:border-gray-700 dark:hover:bg-gray-800">
              <div className="flex items-center gap-2 text-sm">
                <MapPin size={15} className={shareLocation ? "text-brand-600" : "text-gray-400"} />
                <span>Показывать местоположение на карте</span>
              </div>
              <div className="relative">
                <input
                  type="checkbox"
                  className="sr-only"
                  checked={shareLocation}
                  onChange={(e) => setShareLocation(e.target.checked)}
                />
                <div className={`h-6 w-11 rounded-full transition-colors ${shareLocation ? "bg-brand-600" : "bg-gray-300 dark:bg-gray-600"}`} />
                <div className={`absolute top-0.5 h-5 w-5 rounded-full bg-white shadow transition-transform ${shareLocation ? "translate-x-5" : "translate-x-0.5"}`} />
              </div>
            </label>
            {error && (
              <div className="rounded-lg bg-red-50 px-4 py-3 text-sm text-red-600 dark:bg-red-900/20">
                {error}
              </div>
            )}
            <button onClick={startStream} disabled={loading} className="btn-primary w-full">
              {loading ? "Запускаем…" : "Начать эфир"}
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-7xl px-4 py-4">
      <LiveKitRoom
        token={token}
        serverUrl={livekitUrl}
        connect={true}
        video={true}
        audio={true}
        className="contents"
      >
        <StreamerRoom title={title} streamId={streamId} locationEnabled={locationEnabled} onEnd={endStream} />
      </LiveKitRoom>
    </div>
  );
}
