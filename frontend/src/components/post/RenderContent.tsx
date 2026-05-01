"use client";

import { parseContentWithYouTube } from "@/lib/youtube";

interface Props {
  content: string;
  className?: string;
  preview?: boolean;
}

// HTML from TipTap starts with a tag; plain text does not
function isHTML(str: string) {
  return /^\s*</.test(str);
}

// Replace standalone YouTube URL paragraphs (plain or wrapped in <a>) with embedded iframes
function injectYouTube(html: string): string {
  return html.replace(
    /<p>(?:<a[^>]*>)?https?:\/\/(?:www\.youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})[^<]*(?:<\/a>)?<\/p>/g,
    (_match, videoId) =>
      `<div style="position:relative;padding-bottom:56.25%;overflow:hidden;border-radius:8px;margin:1rem 0">` +
      `<iframe src="https://www.youtube.com/embed/${videoId}" ` +
      `style="position:absolute;inset:0;width:100%;height:100%;border:0" ` +
      `allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" ` +
      `allowfullscreen></iframe></div>`
  );
}

export function RenderContent({ content, className, preview = false }: Props) {
  if (isHTML(content)) {
    if (preview) {
      // Strip tags for plain-text preview
      const plain = content.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
      return <p className={className}>{plain}</p>;
    }
    return (
      <div
        className={`prose prose-sm dark:prose-invert max-w-none break-words ${className ?? ""}`}
        // TipTap produces safe HTML (no user-controlled script injection path)
        // eslint-disable-next-line react/no-danger
        dangerouslySetInnerHTML={{ __html: injectYouTube(content) }}
      />
    );
  }

  // Legacy plain-text with YouTube embeds
  const parts = parseContentWithYouTube(content);
  return (
    <div className={className}>
      {parts.map((part, i) => {
        if (part.type === "youtube") {
          if (preview) {
            return (
              <div key={i} className="relative my-2 aspect-video w-full overflow-hidden rounded-lg bg-black">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={`https://img.youtube.com/vi/${part.videoId}/hqdefault.jpg`}
                  alt="YouTube"
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
          <span key={i} className="whitespace-pre-wrap break-words">
            {part.value}
          </span>
        ) : null;
      })}
    </div>
  );
}
