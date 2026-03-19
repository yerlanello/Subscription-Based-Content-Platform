"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { postsApi } from "@/lib/api";
import { Post, Comment } from "@/lib/types";
import { useAuth } from "@/hooks/useAuth";
import { formatDistanceToNow } from "date-fns";
import { ru } from "date-fns/locale";
import { Heart, Lock, MessageCircle, Trash2 } from "lucide-react";
import Link from "next/link";
import { useState, useEffect } from "react";
import { useRouter, useSearchParams } from "next/navigation";

export default function PostPage({ params }: { params: { id: string } }) {
  const { id } = params;
  const { user, isLoading: authLoading } = useAuth();
  const router = useRouter();
  const searchParams = useSearchParams();
  const isLockedHint = searchParams.get("locked") === "1";
  const queryClient = useQueryClient();
  const [comment, setComment] = useState("");

  useEffect(() => {
    if (!authLoading && !user) router.push("/register");
  }, [user, authLoading, router]);

  const { data: post, isLoading, error } = useQuery({
    queryKey: ["post", id],
    queryFn: () => postsApi.get(id).then((r) => r.data.data as Post),
  });

  const { data: comments } = useQuery({
    queryKey: ["comments", id],
    queryFn: () => postsApi.getComments(id).then((r) => r.data.data as Comment[]),
    enabled: !!post,
  });

  const likeMutation = useMutation({
    mutationFn: () =>
      post!.is_liked ? postsApi.unlike(id) : postsApi.like(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["post", id] }),
  });

  const commentMutation = useMutation({
    mutationFn: (content: string) => postsApi.createComment(id, { content }),
    onSuccess: () => {
      setComment("");
      queryClient.invalidateQueries({ queryKey: ["comments", id] });
    },
  });

  const deleteCommentMutation = useMutation({
    mutationFn: (commentId: string) => postsApi.deleteComment(id, commentId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["comments", id] }),
  });

  // Мгновенный показ если знаем что пост платный (передаётся через ?locked=1)
  if (isLockedHint && isLoading) {
    return (
      <div className="mx-auto max-w-3xl px-4 py-8 animate-fade-in">
        <div className="card flex flex-col items-center gap-4 py-20 text-center">
          <Lock size={40} className="text-brand-400" />
          <h2 className="text-xl font-semibold">Контент только для подписчиков</h2>
          <p className="text-gray-500">Оформите подписку на автора чтобы читать этот пост</p>
        </div>
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="mx-auto max-w-3xl px-4 py-8">
        <div className="card p-6 space-y-4">
          <div className="skeleton h-4 w-24" />
          <div className="skeleton h-8 w-3/4" />
          <div className="skeleton h-4 w-full" />
          <div className="skeleton h-4 w-5/6" />
          <div className="skeleton h-4 w-4/6" />
        </div>
      </div>
    );
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const status = (error as any)?.response?.status;
  if (status === 402 || status === 403) {
    return (
      <div className="mx-auto max-w-3xl px-4 py-8">
        <div className="card flex flex-col items-center gap-4 py-20 text-center">
          <Lock size={40} className="text-brand-400" />
          <h2 className="text-xl font-semibold">Контент только для подписчиков</h2>
          <p className="text-gray-500">Оформите подписку на автора чтобы читать этот пост</p>
          {post?.creator?.username && (
            <Link href={`/${post.creator.username}`} className="btn-primary">
              Перейти к автору
            </Link>
          )}
        </div>
      </div>
    );
  }

  if (!post) return <div className="py-20 text-center text-gray-400">Пост не найден</div>;

  return (
    <div className="mx-auto max-w-3xl px-4 py-8">
      <article className="card p-6 sm:p-8">
        {/* Header */}
        <div className="mb-6 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-brand-100 text-brand-600 font-semibold">
              {post.creator?.username?.[0]?.toUpperCase() ?? "?"}
            </div>
            <div>
              <Link
                href={`/${post.creator?.username}`}
                className="font-medium hover:text-brand-600"
              >
                {post.creator?.username}
              </Link>
              <p className="text-xs text-gray-400">
                {post.published_at
                  ? formatDistanceToNow(new Date(post.published_at), {
                      addSuffix: true,
                      locale: ru,
                    })
                  : "Черновик"}
              </p>
            </div>
          </div>
          {!post.is_free && (
            <span className="flex items-center gap-1 rounded-full bg-brand-50 px-3 py-1 text-xs text-brand-600">
              <Lock size={10} /> Для подписчиков
            </span>
          )}
        </div>

        <h1 className="mb-4 text-2xl font-bold">{post.title}</h1>

        {post.content && (
          <div className="prose max-w-none text-gray-700 whitespace-pre-wrap">
            {post.content}
          </div>
        )}

        {/* Attachments */}
        {post.attachments && post.attachments.length > 0 && (
          <div className="mt-6 space-y-3">
            {post.attachments.map((a) => {
              const mime = a.mime_type ?? "";
              if (mime.startsWith("image/"))
                return (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img key={a.id} src={a.url} alt="" className="rounded-lg max-h-[500px] w-full object-contain" />
                );
              if (mime.startsWith("video/"))
                return <video key={a.id} src={a.url} controls className="w-full rounded-lg max-h-[500px]" />;
              if (mime.startsWith("audio/"))
                return <audio key={a.id} src={a.url} controls className="w-full" />;
              return null;
            })}
          </div>
        )}

        {/* Actions */}
        <div className="mt-6 flex items-center gap-4 border-t pt-4">
          {user && (
            <button
              onClick={() => likeMutation.mutate()}
              className={`flex items-center gap-2 text-sm transition-colors ${
                post.is_liked ? "text-red-500" : "text-gray-500 hover:text-red-500"
              }`}
            >
              <Heart size={18} className={post.is_liked ? "fill-red-500" : ""} />
              {post.likes_count ?? 0}
            </button>
          )}
          <span className="flex items-center gap-2 text-sm text-gray-500">
            <MessageCircle size={18} />
            {comments?.length ?? 0}
          </span>
        </div>
      </article>

      {/* Comments */}
      <div className="mt-6 card p-6">
        <h2 className="mb-4 font-semibold">Комментарии</h2>

        {user && (
          <form
            onSubmit={(e) => {
              e.preventDefault();
              if (comment.trim()) commentMutation.mutate(comment.trim());
            }}
            className="mb-6 flex gap-3"
          >
            <input
              className="input flex-1"
              placeholder="Написать комментарий..."
              value={comment}
              onChange={(e) => setComment(e.target.value)}
            />
            <button
              type="submit"
              disabled={!comment.trim() || commentMutation.isPending}
              className="btn-primary"
            >
              Отправить
            </button>
          </form>
        )}

        <div className="space-y-4">
          {!comments || comments.length === 0 ? (
            <p className="text-sm text-gray-400">Комментариев пока нет</p>
          ) : (
            comments.map((c) => (
              <div key={c.id} className="flex gap-3">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gray-100 text-sm font-semibold">
                  {c.author?.username?.[0]?.toUpperCase()}
                </div>
                <div className="flex-1">
                  <div className="flex items-center justify-between">
                    <span className="text-sm font-medium">{c.author?.username}</span>
                    <span className="text-xs text-gray-400">
                      {formatDistanceToNow(new Date(c.created_at), {
                        addSuffix: true,
                        locale: ru,
                      })}
                    </span>
                  </div>
                  <p className="mt-1 text-sm text-gray-700">{c.content}</p>
                </div>
                {user?.id === c.user_id && (
                  <button
                    onClick={() => deleteCommentMutation.mutate(c.id)}
                    className="text-gray-300 hover:text-red-400"
                  >
                    <Trash2 size={14} />
                  </button>
                )}
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
