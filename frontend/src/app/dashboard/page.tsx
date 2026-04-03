"use client";

import { useAuth } from "@/hooks/useAuth";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { creatorsApi, postsApi } from "@/lib/api";
import { CreatorPage, Post } from "@/lib/types";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import Link from "next/link";
import { formatDistanceToNow } from "date-fns";
import { ru as ruLocale, enUS, kk as kkLocale } from "date-fns/locale";
import { PlusCircle, Eye, EyeOff, Trash2, Send, Pencil, Pin, PinOff } from "lucide-react";
import { BecomeCreatorModal } from "@/components/creator/BecomeCreatorModal";
import { ConfirmModal } from "@/components/ui/ConfirmModal";
import { formatPrice } from "@/lib/auth";
import { useT } from "@/hooks/useT";
import { useLocaleStore } from "@/store/localeStore";

const dateFnsLocales = { ru: ruLocale, en: enUS, kk: kkLocale };

export default function DashboardPage() {
  const { user, isLoading } = useAuth();
  const router = useRouter();
  const queryClient = useQueryClient();
  const [showModal, setShowModal] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<string | null>(null);
  const t = useT();
  const locale = useLocaleStore((s) => s.locale);
  const dateLocale = dateFnsLocales[locale];

  useEffect(() => {
    if (!isLoading && !user) router.push("/login");
  }, [user, isLoading, router]);

  const { data: creator } = useQuery({
    queryKey: ["my-creator"],
    queryFn: () =>
      creatorsApi.getByUsername(user!.username).then((r) => r.data.data as CreatorPage),
    enabled: !!user,
  });

  const { data: posts } = useQuery({
    queryKey: ["my-posts", user?.username],
    queryFn: () =>
      creatorsApi.getPosts(user!.username, { limit: 50 }).then((r) => r.data.data as Post[]),
    enabled: !!user && (user.role === "creator" || user.role === "both"),
  });

  const publishMutation = useMutation({
    mutationFn: (id: string) => postsApi.publish(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["my-posts"] }),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => postsApi.delete(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["my-posts"] }),
  });

  const pinMutation = useMutation({
    mutationFn: ({ id, pinned }: { id: string; pinned: boolean }) =>
      pinned ? postsApi.unpin(id) : postsApi.pin(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["my-posts"] }),
  });

  if (isLoading || !user) return null;

  const isCreator = user.role === "creator" || user.role === "both";

  return (
    <div className="mx-auto max-w-5xl px-4 py-8">
      <div className="mb-8 flex items-center justify-between">
        <h1 className="text-2xl font-bold">{t.dashboard.title}</h1>
        {isCreator && (
          <Link href="/dashboard/posts/new" className="btn-primary">
            <PlusCircle size={16} />
            {t.dashboard.newPost}
          </Link>
        )}
      </div>

      {!isCreator ? (
        <div className="card flex flex-col items-center gap-4 py-16 text-center">
          <p className="text-lg font-medium">{t.dashboard.notCreator}</p>
          <p className="text-gray-500">{t.dashboard.notCreatorHint}</p>
          <button onClick={() => setShowModal(true)} className="btn-primary">
            {t.dashboard.becomeCreator}
          </button>
          {showModal && <BecomeCreatorModal onClose={() => setShowModal(false)} />}
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-8 lg:grid-cols-3">
          {/* Sidebar */}
          <aside className="lg:col-span-1 space-y-4">
            <div className="card p-5">
              <h2 className="mb-3 font-semibold">{t.dashboard.myProfile}</h2>
              {creator?.profile && (
                <>
                  <p className="text-sm text-gray-600">{creator.profile.display_name}</p>
                  {creator.profile.description && (
                    <p className="mt-1 text-xs text-gray-400 line-clamp-3">
                      {creator.profile.description}
                    </p>
                  )}
                  <p className="mt-2 text-sm font-medium text-brand-600">
                    {creator.profile.subscription_price_cents === 0
                      ? t.creator.freeSubscription
                      : formatPrice(creator.profile.subscription_price_cents, t.billing.perMonth)}
                  </p>
                </>
              )}
              <Link
                href="/dashboard/settings"
                className="btn-outline mt-3 w-full text-sm"
              >
                {t.dashboard.editProfile}
              </Link>
            </div>
          </aside>

          {/* Posts table */}
          <div className="lg:col-span-2">
            <div className="card overflow-hidden">
              <div className="border-b px-5 py-4 font-semibold">{t.dashboard.myPosts}</div>
              {!posts || posts.length === 0 ? (
                <div className="px-5 py-12 text-center text-gray-400 text-sm">
                  {t.dashboard.noPosts}
                </div>
              ) : (
                <ul className="divide-y">
                  {posts.map((post) => (
                    <li key={post.id} className="flex items-center justify-between gap-3 px-5 py-4">
                      <div className="min-w-0">
                        <div className="flex items-center gap-1.5">
                          {post.is_pinned && (
                            <Pin size={13} className="shrink-0 text-brand-500" />
                          )}
                          <Link
                            href={`/posts/${post.id}`}
                            className="block truncate font-medium hover:text-brand-600"
                          >
                            {post.title}
                          </Link>
                        </div>
                        <div className="flex items-center gap-2 mt-0.5 text-xs text-gray-400">
                          <span className={post.is_free ? "text-green-600" : "text-brand-600"}>
                            {post.is_free ? t.post.free : t.post.paid}
                          </span>
                          <span>·</span>
                          <span>
                            {formatDistanceToNow(new Date(post.created_at), {
                              addSuffix: true,
                              locale: dateLocale,
                            })}
                          </span>
                        </div>
                      </div>
                      <div className="flex shrink-0 items-center gap-2">
                        {post.is_published && (
                          <button
                            onClick={() => pinMutation.mutate({ id: post.id, pinned: !!post.is_pinned })}
                            disabled={pinMutation.isPending}
                            title={post.is_pinned ? t.dashboard.unpin : t.dashboard.pin}
                            className={`btn-ghost p-2 ${post.is_pinned ? "text-brand-500" : "text-gray-400"}`}
                          >
                            {post.is_pinned ? <PinOff size={15} /> : <Pin size={15} />}
                          </button>
                        )}
                        {!post.is_published && (
                          <button
                            onClick={() => publishMutation.mutate(post.id)}
                            disabled={publishMutation.isPending}
                            title={t.dashboard.publish}
                            className="btn-ghost p-2 text-green-600"
                          >
                            <Send size={15} />
                          </button>
                        )}
                        <span title={post.is_published ? t.dashboard.published : t.post.draft}>
                          {post.is_published ? (
                            <Eye size={15} className="text-gray-400" />
                          ) : (
                            <EyeOff size={15} className="text-gray-300" />
                          )}
                        </span>
                        <Link
                          href={`/dashboard/posts/${post.id}`}
                          className="btn-ghost p-2 text-gray-500"
                          title={t.dashboard.editProfile}
                        >
                          <Pencil size={15} />
                        </Link>
                        <button
                          onClick={() => setDeleteTarget(post.id)}
                          className="btn-ghost p-2 text-red-400"
                        >
                          <Trash2 size={15} />
                        </button>
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </div>
        </div>
      )}

      {deleteTarget && (
        <ConfirmModal
          title={t.dashboard.deleteTitle}
          message={t.dashboard.deleteMessage}
          confirmLabel={t.dashboard.deleteConfirm}
          danger
          onConfirm={() => deleteMutation.mutate(deleteTarget)}
          onClose={() => setDeleteTarget(null)}
        />
      )}
    </div>
  );
}
