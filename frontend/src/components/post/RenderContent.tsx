"use client";

import { parseContentWithYouTube } from "@/lib/youtube";

interface Props {
  content: string;
  className?: string;
  /** Если true — показывает превью-миниатюру вместо плеера */
  preview?: boolean;
}

export function RenderContent({ content, className, preview = false }: Props) {
  const parts = parseContentWithYouTube(content);

  return (
    <div className={className}>
      {parts.map((part, i) => {
        if (part.type === "youtube") {
          if (preview) {
            return (
              <div
                key={i}
                className="relative my-2 aspect-video w-full overflow-hidden rounded-lg bg-black"
              >
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={`https://img.youtube.com/vi/${part.videoId}/hqdefault.jpg`}
                  alt="YouTube видео"
                  className="h-full w-full object-cover opacity-80"
                />
                <div className="absolute inset-0 flex items-center justify-center">
                  <div className="flex h-12 w-12 items-center justify-center rounded-full bg-red-600 text-white shadow-lg">
                    <svg viewBox="0 0 24 24" fill="currentColor" className="h-5 w-5 ml-0.5">
                      <path d="M8 5v14l11-7z" />
                    </svg>
                  </div>
                </div>
              </div>
            );
          }
          return (
            <div key={i} className="my-4 aspect-video w-full overflow-hidden rounded-lg">
              <iframe
                src={`https://www.youtube.com/embed/${part.videoId}`}
                title="YouTube video"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                allowFullScreen
                className="h-full w-full"
              />
            </div>
          );
        }
        return part.value ? (
          <span key={i} className="whitespace-pre-wrap">
            {part.value}
          </span>
        ) : null;
      })}
    </div>
  );
}
