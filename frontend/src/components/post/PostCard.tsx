"use client";

import Link from "next/link";
import { Post } from "@/lib/types";
import { formatDistanceToNow } from "date-fns";
import { ru } from "date-fns/locale";
import { Heart, Lock, MessageCircle } from "lucide-react";

interface Props {
  post: Post;
}

export function PostCard({ post }: Props) {
  const isLocked = !post.is_free && post.content === null;

  return (
    <article className="card p-5 hover:shadow-md transition-shadow">
      {/* Meta */}
      <div className="mb-3 flex items-center justify-between">
        {post.creator && (
          <Link href={`/${post.creator.username}`} className="flex items-center gap-2 text-sm hover:text-brand-600">
            {post.creator.avatar_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={post.creator.avatar_url} alt={post.creator.username} className="h-7 w-7 rounded-full object-cover" />
            ) : (
              <div className="flex h-7 w-7 items-center justify-center rounded-full bg-brand-100 text-xs font-semibold text-brand-600">
                {post.creator.username[0].toUpperCase()}
              </div>
            )}
            <span className="font-medium">{post.creator.username}</span>
          </Link>
        )}
        <div className="flex items-center gap-2">
          {!post.is_free && (
            <span className="flex items-center gap-1 rounded-full bg-brand-50 px-2 py-0.5 text-xs text-brand-600">
              <Lock size={10} /> Платно
            </span>
          )}
          <span className="text-xs text-gray-400">
            {post.published_at
              ? formatDistanceToNow(new Date(post.published_at), {
                  addSuffix: true,
                  locale: ru,
                })
              : "Черновик"}
          </span>
        </div>
      </div>

      <Link href={`/posts/${post.id}${!post.is_free ? "?locked=1" : ""}`}>
        <h2 className="mb-2 font-semibold hover:text-brand-600 transition-colors">
          {post.title}
        </h2>
      </Link>

      {isLocked ? (
        <div className="flex items-center gap-2 rounded-lg bg-gray-50 px-4 py-3 text-sm text-gray-400">
          <Lock size={14} />
          Подпишитесь чтобы читать этот пост
        </div>
      ) : (
        post.content && (
          <p className="text-sm text-gray-600 line-clamp-3 whitespace-pre-wrap">
            {post.content}
          </p>
        )
      )}

      {/* Attachments preview */}
      {post.attachments && post.attachments.length > 0 && (
        <div className="mt-3 space-y-2">
          {post.attachments.map((a) => {
            const mime = a.mime_type ?? "";
            if (mime.startsWith("image/"))
              return (
                // eslint-disable-next-line @next/next/no-img-element
                <img key={a.id} src={a.url} alt="" className="max-h-64 w-full rounded-lg object-cover" />
              );
            if (mime.startsWith("video/"))
              return <video key={a.id} src={a.url} controls className="w-full rounded-lg max-h-64" />;
            if (mime.startsWith("audio/"))
              return <audio key={a.id} src={a.url} controls className="w-full" />;
            return null;
          })}
        </div>
      )}

      {/* Actions */}
      <div className="mt-4 flex items-center gap-4 text-sm text-gray-400">
        <span className="flex items-center gap-1">
          <Heart size={14} className={post.is_liked ? "fill-red-500 text-red-500" : ""} />
          {post.likes_count ?? 0}
        </span>
        <span className="flex items-center gap-1">
          <MessageCircle size={14} />
          {post.comments_count ?? 0}
        </span>
        <Link href={`/posts/${post.id}${!post.is_free ? "?locked=1" : ""}`} className="ml-auto text-brand-600 hover:underline">
          Читать →
        </Link>
      </div>
    </article>
  );
}
