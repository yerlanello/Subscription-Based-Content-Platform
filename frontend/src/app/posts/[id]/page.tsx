"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { postsApi } from "@/lib/api";
import { Post, Comment } from "@/lib/types";
import { useAuth } from "@/hooks/useAuth";
import { formatDistanceToNow } from "date-fns";
import { ru as ruLocale, enUS, kk as kkLocale } from "date-fns/locale";
import { Lock, MessageCircle, Trash2, ChevronDown, ChevronUp, CornerDownRight, Languages } from "lucide-react";
import { RenderContent } from "@/components/post/RenderContent";
import { LikeButton } from "@/components/post/LikeButton";
import Link from "next/link";
import { useState, useEffect, useRef } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useT } from "@/hooks/useT";
import { useLocaleStore } from "@/store/localeStore";
import type { Locale } from "date-fns";
import type { User } from "@/lib/types";
import type { Translations } from "@/locales/ru";

const dateFnsLocales = { ru: ruLocale, en: enUS, kk: kkLocale };

const avatarSizes: Record<number, string> = {
  7:  "h-7 w-7",
  8:  "h-8 w-8",
  10: "h-10 w-10",
};

function Avatar({ url, username, size = 8 }: { url: string | null | undefined; username?: string; size?: number }) {
  const dim = avatarSizes[size] ?? "h-8 w-8";
  if (url)
    return <img src={url} alt={username ?? ""} className={`${dim} shrink-0 rounded-full object-cover`} />; // eslint-disable-line @next/next/no-img-element
  return (
    <div className={`${dim} flex shrink-0 items-center justify-center rounded-full bg-gray-100 dark:bg-gray-700 text-xs font-semibold`}>
      {username?.[0]?.toUpperCase()}
    </div>
  );
}

function CommentRow({
  comment,
  postId,
  user,
  dateLocale,
  onReply,
  onDelete,
  onLikeToggle,
  t,
}: {
  comment: Comment;
  postId: string;
  user: User | null;
  dateLocale: Locale;
  onReply: () => void;
  onDelete: () => void;
  onLikeToggle: () => void;
  t: Translations;
}) {
  return (
    <div className="flex gap-3">
      <Avatar url={comment.author?.avatar_url} username={comment.author?.username} size={8} />
      <div className="flex-1 min-w-0">
        <div className="flex items-center justify-between gap-2">
          <span className="text-sm font-medium">{comment.author?.username}</span>
          <span className="text-xs text-gray-400 shrink-0">
            {formatDistanceToNow(new Date(comment.created_at), { addSuffix: true, locale: dateLocale })}
          </span>
        </div>
        <p className="mt-1 text-sm text-gray-700 dark:text-gray-300">{comment.content}</p>
        <div className="flex items-center gap-3 mt-1">
          {user && (
            <button
              onClick={onReply}
              className="flex items-center gap-1 text-xs text-gray-400 hover:text-brand-500 transition-colors"
            >
              <CornerDownRight size={12} />
              {t.post.reply}
            </button>
          )}
          {user && (
            <LikeButton
              liked={!!comment.is_liked}
              count={comment.likes_count ?? 0}
              onClick={onLikeToggle}
              size="sm"
            />
          )}
          {user?.id === comment.user_id && (
            <button onClick={onDelete} className="text-gray-300 hover:text-red-400 transition-colors">
              <Trash2 size={13} />
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

export default function PostPage({ params }: { params: { id: string } }) {
  const { id } = params;
  const { user, isLoading: authLoading } = useAuth();
  const router = useRouter();
  const searchParams = useSearchParams();
  const isLockedHint = searchParams.get("locked") === "1";
  const queryClient = useQueryClient();
  const t = useT();
  const locale = useLocaleStore((s) => s.locale);
  const dateLocale = dateFnsLocales[locale];

  const [comment, setComment] = useState("");
  const [contentExpanded, setContentExpanded] = useState(false);
  const [needsExpand, setNeedsExpand] = useState(false);
  const contentRef = useRef<HTMLDivElement>(null);
  const [translated, setTranslated] = useState<{ title: string; content: string } | null>(null);
  const [isTranslating, setIsTranslating] = useState(false);
  const [showTranslated, setShowTranslated] = useState(false);
  const [translateError, setTranslateError] = useState(false);

  const translatePost = async () => {
    if (translated) { setShowTranslated(true); return; }
    setIsTranslating(true);
    setTranslateError(false);
    try {
      const tl = locale;
      const gt = async (text: string) => {
        const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=${tl}&dt=t&q=${encodeURIComponent(text)}`;
        const res = await fetch(url);
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const data: any = await res.json();
        return (data[0] as [string][]).map((item) => item[0]).join("");
      };
      const [tTitle, tContent] = await Promise.all([
        gt(post!.title),
        post!.content ? gt(post!.content) : Promise.resolve(""),
      ]);
      setTranslated({ title: tTitle, content: tContent });
      setShowTranslated(true);
    } catch {
      setTranslateError(true);
    } finally {
      setIsTranslating(false);
    }
  };

  // replyingTo: { rootId, atUsername } — always attaches to root comment
  const [replyingTo, setReplyingTo] = useState<{ rootId: string; atUsername: string } | null>(null);
  const [replyText, setReplyText] = useState("");
  const [expandedReplies, setExpandedReplies] = useState<Set<string>>(new Set());

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
    mutationFn: () => post!.is_liked ? postsApi.unlike(id) : postsApi.like(id),
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

  const likeCommentMutation = useMutation({
    mutationFn: ({ commentId, liked }: { commentId: string; liked: boolean }) =>
      liked ? postsApi.unlikeComment(id, commentId) : postsApi.likeComment(id, commentId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["comments", id] }),
  });

  const replyMutation = useMutation({
    mutationFn: ({ content, parentId }: { content: string; parentId: string }) =>
      postsApi.createComment(id, { content, parent_id: parentId }),
    onSuccess: (_, { parentId }) => {
      // auto-expand the thread we just replied to
      setExpandedReplies((prev) => { const s = new Set(prev); s.add(parentId); return s; });
      setReplyingTo(null);
      setReplyText("");
      queryClient.invalidateQueries({ queryKey: ["comments", id] });
    },
  });

  useEffect(() => {
    if (!contentRef.current) return;
    setNeedsExpand(contentRef.current.scrollHeight > contentRef.current.clientHeight);
  }, [post?.content, showTranslated, translated]);

  const toggleReplies = (commentId: string) => {
    setExpandedReplies((prev) => {
      const next = new Set(prev);
      if (next.has(commentId)) next.delete(commentId);
      else next.add(commentId);
      return next;
    });
  };

  const startReply = (rootId: string, atUsername: string, initialText = "") => {
    setReplyingTo({ rootId, atUsername });
    setReplyText(initialText);
  };

  const submitReply = (e: React.FormEvent) => {
    e.preventDefault();
    if (!replyingTo || !replyText.trim()) return;
    replyMutation.mutate({ content: replyText.trim(), parentId: replyingTo.rootId });
  };

  if (isLockedHint && isLoading) {
    return (
      <div className="mx-auto max-w-3xl px-4 py-8 animate-fade-in">
        <div className="card flex flex-col items-center gap-4 py-20 text-center">
          <Lock size={40} className="text-brand-400" />
          <h2 className="text-xl font-semibold">{t.post.lockedTitle}</h2>
          <p className="text-gray-500">{t.post.lockedHint}</p>
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
          <h2 className="text-xl font-semibold">{t.post.lockedTitle}</h2>
          <p className="text-gray-500">{t.post.lockedHint}</p>
          {post?.creator?.username && (
            <Link href={`/${post.creator.username}`} className="btn-primary">
              {t.post.goToCreator}
            </Link>
          )}
        </div>
      </div>
    );
  }

  if (!post) return <div className="py-20 text-center text-gray-400">{t.post.notFound}</div>;

  return (
    <div className="mx-auto max-w-3xl px-4 py-8">
      <article className="card p-6 sm:p-8 overflow-hidden">
        <div className="mb-6 flex items-center justify-between gap-3 min-w-0">
          <div className="flex items-center gap-3 min-w-0">
            <Avatar url={post.creator?.avatar_url} username={post.creator?.username} size={10} />
            <div>
              <Link href={`/${post.creator?.username}`} className="font-medium hover:text-brand-600">
                {post.creator?.username}
              </Link>
              <p className="text-xs text-gray-400">
                {post.published_at
                  ? formatDistanceToNow(new Date(post.published_at), { addSuffix: true, locale: dateLocale })
                  : t.post.draft}
              </p>
            </div>
          </div>
          {!post.is_free && (
            <span className="flex items-center gap-1 rounded-full bg-brand-50 px-3 py-1 text-xs text-brand-600">
              <Lock size={10} /> {t.post.forSubscribers}
            </span>
          )}
        </div>

        <div className="mb-4 flex items-start justify-between gap-3">
          <h1 className="text-2xl font-bold break-words min-w-0">
            {showTranslated && translated ? translated.title : post.title}
          </h1>
          <button
            onClick={translatePost}
            disabled={isTranslating}
            title={t.post.translate}
            className="shrink-0 flex items-center gap-1.5 text-xs text-gray-400 hover:text-brand-500 transition-colors border border-gray-200 dark:border-gray-700 rounded-full px-3 py-1.5 mt-1"
          >
            <Languages size={13} />
            {isTranslating ? t.post.translating : t.post.translate}
          </button>
        </div>

        {/* Translate toggle */}
        {translated && (
          <div className="mb-3 flex items-center gap-2">
            <button
              onClick={() => setShowTranslated(false)}
              className={`text-xs px-3 py-1 rounded-full border transition-colors ${!showTranslated ? "bg-brand-500 text-white border-brand-500" : "border-gray-200 dark:border-gray-700 text-gray-400 hover:text-brand-500"}`}
            >
              {t.post.showOriginal}
            </button>
            <button
              onClick={() => setShowTranslated(true)}
              className={`text-xs px-3 py-1 rounded-full border transition-colors ${showTranslated ? "bg-brand-500 text-white border-brand-500" : "border-gray-200 dark:border-gray-700 text-gray-400 hover:text-brand-500"}`}
            >
              {t.post.translated}
            </button>
          </div>
        )}
        {translateError && (
          <p className="mb-3 text-xs text-red-500">{t.post.translateError}</p>
        )}

        {post.content && (
          <>
            <div
              ref={contentRef}
              className={!contentExpanded ? "relative max-h-[600px] overflow-hidden" : ""}
            >
              <RenderContent
                content={(showTranslated && translated?.content) ? translated.content : post.content}
                className="prose max-w-none text-gray-700 dark:text-gray-300 break-words"
              />
              {!contentExpanded && needsExpand && (
                <div className="pointer-events-none absolute bottom-0 left-0 right-0 h-28 bg-gradient-to-t from-white dark:from-gray-900 to-transparent" />
              )}
            </div>
            {needsExpand && (
              <button
                onClick={() => setContentExpanded((v) => !v)}
                className="mt-3 text-sm font-medium text-brand-600 hover:text-brand-700 transition-colors"
              >
                {contentExpanded ? t.postEditor.collapse : t.postEditor.readMore}
              </button>
            )}
          </>
        )}

        {post.attachments && post.attachments.length > 0 && (
          <div className="mt-6 space-y-3">
            {post.attachments.map((a) => {
              const mime = a.mime_type ?? "";
              if (mime.startsWith("image/"))
                return <img key={a.id} src={a.url} alt="" className="rounded-lg max-h-[500px] w-full object-contain" />; // eslint-disable-line @next/next/no-img-element
              if (mime.startsWith("video/"))
                return <video key={a.id} src={a.url} controls className="w-full rounded-lg max-h-[500px]" />;
              if (mime.startsWith("audio/"))
                return <audio key={a.id} src={a.url} controls className="w-full" />;
              return null;
            })}
          </div>
        )}

        <div className="mt-6 flex items-center gap-4 border-t dark:border-gray-700 pt-4">
          {user && (
            <LikeButton
              liked={!!post.is_liked}
              count={post.likes_count ?? 0}
              onClick={() => likeMutation.mutate()}
              disabled={likeMutation.isPending}
            />
          )}
          <span className="flex items-center gap-2 text-sm text-gray-500">
            <MessageCircle size={18} />
            {comments?.length ?? 0}
          </span>
        </div>
      </article>

      {/* Comments section */}
      <div className="mt-6 card p-6">
        <h2 className="mb-4 font-semibold">{t.post.comments}</h2>

        {user && (
          <form
            onSubmit={(e) => { e.preventDefault(); if (comment.trim()) commentMutation.mutate(comment.trim()); }}
            className="mb-6 flex gap-3"
          >
            <input
              className="input flex-1"
              placeholder={t.post.commentPlaceholder}
              value={comment}
              onChange={(e) => setComment(e.target.value)}
            />
            <button type="submit" disabled={!comment.trim() || commentMutation.isPending} className="btn-primary">
              {t.post.send}
            </button>
          </form>
        )}

        <div className="space-y-6">
          {!comments || comments.length === 0 ? (
            <p className="text-sm text-gray-400">{t.post.noComments}</p>
          ) : (
            comments.map((c) => {
              const repliesExpanded = expandedReplies.has(c.id);
              const replyCount = c.replies?.length ?? 0;
              const isReplyingHere = replyingTo?.rootId === c.id;

              return (
                <div key={c.id}>
                  {/* Root comment */}
                  <CommentRow
                    comment={c}
                    postId={id}
                    user={user}
                    dateLocale={dateLocale}
                    onReply={() => startReply(c.id, c.author?.username ?? "")}
                    onDelete={() => deleteCommentMutation.mutate(c.id)}
                    onLikeToggle={() => likeCommentMutation.mutate({ commentId: c.id, liked: !!c.is_liked })}
                    t={t}
                  />

                  {/* Replies area (indented) */}
                  {(replyCount > 0 || isReplyingHere) && (
                    <div className="ml-11 mt-2">
                      {/* Show/hide toggle */}
                      {replyCount > 0 && (
                        <button
                          onClick={() => toggleReplies(c.id)}
                          className="flex items-center gap-1 text-sm font-medium text-brand-500 hover:text-brand-400 transition-colors mb-3"
                        >
                          {repliesExpanded
                            ? <><ChevronUp size={15} /> {t.post.hideReplies}</>
                            : <><ChevronDown size={15} /> {t.post.showReplies} ({replyCount})</>
                          }
                        </button>
                      )}

                      {/* Replies list */}
                      {repliesExpanded && replyCount > 0 && (
                        <div className="space-y-4 pl-3 border-l-2 border-gray-100 dark:border-gray-800 mb-3">
                          {c.replies!.map((reply) => (
                            <CommentRow
                              key={reply.id}
                              comment={reply}
                              postId={id}
                              user={user}
                              dateLocale={dateLocale}
                              onReply={() => startReply(c.id, reply.author?.username ?? "", `@${reply.author?.username} `)}
                              onDelete={() => deleteCommentMutation.mutate(reply.id)}
                              onLikeToggle={() => likeCommentMutation.mutate({ commentId: reply.id, liked: !!reply.is_liked })}
                              t={t}
                            />
                          ))}
                        </div>
                      )}

                      {/* Reply form */}
                      {isReplyingHere && (
                        <form onSubmit={submitReply} className="flex gap-2 items-center">
                          <Avatar url={user?.avatar_url} username={user?.username} size={7} />
                          <input
                            autoFocus
                            className="input flex-1 text-sm py-1.5"
                            placeholder={`@${replyingTo.atUsername} ${t.post.replyPlaceholder}`}
                            value={replyText}
                            onChange={(e) => setReplyText(e.target.value)}
                          />
                          <button
                            type="submit"
                            disabled={!replyText.trim() || replyMutation.isPending}
                            className="btn-primary text-sm py-1.5 px-3"
                          >
                            {t.post.send}
                          </button>
                          <button
                            type="button"
                            onClick={() => setReplyingTo(null)}
                            className="btn-ghost text-sm py-1.5 px-2"
                          >
                            {t.common.cancel}
                          </button>
                        </form>
                      )}
                    </div>
                  )}
                </div>
              );
            })
          )}
        </div>
      </div>
    </div>
  );
}
