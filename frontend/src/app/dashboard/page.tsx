"use client";

import { useAuth } from "@/hooks/useAuth";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { creatorsApi, postsApi } from "@/lib/api";
import { CreatorPage, Post } from "@/lib/types";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import Link from "next/link";
import { formatDistanceToNow } from "date-fns";
import { ru } from "date-fns/locale";
import { PlusCircle, Eye, EyeOff, Trash2, Send, Pencil } from "lucide-react";
import { BecomeCreatorModal } from "@/components/creator/BecomeCreatorModal";
import { ConfirmModal } from "@/components/ui/ConfirmModal";

export default function DashboardPage() {
  const { user, isLoading } = useAuth();
  const router = useRouter();
  const queryClient = useQueryClient();
  const [showModal, setShowModal] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<string | null>(null);

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

  if (isLoading || !user) return null;

  const isCreator = user.role === "creator" || user.role === "both";

  return (
    <div className="mx-auto max-w-5xl px-4 py-8">
      <div className="mb-8 flex items-center justify-between">
        <h1 className="text-2xl font-bold">Панель автора</h1>
        {isCreator && (
          <Link href="/dashboard/posts/new" className="btn-primary">
            <PlusCircle size={16} />
            Новый пост
          </Link>
        )}
      </div>

      {!isCreator ? (
        <div className="card flex flex-col items-center gap-4 py-16 text-center">
          <p className="text-lg font-medium">Вы ещё не стали автором</p>
          <p className="text-gray-500">Создайте профиль автора чтобы публиковать контент</p>
          <button onClick={() => setShowModal(true)} className="btn-primary">
            Стать автором
          </button>
          {showModal && <BecomeCreatorModal onClose={() => setShowModal(false)} />}
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-8 lg:grid-cols-3">
          {/* Sidebar — профиль */}
          <aside className="lg:col-span-1 space-y-4">
            <div className="card p-5">
              <h2 className="mb-3 font-semibold">Мой профиль</h2>
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
                      ? "Бесплатная подписка"
                      : `${creator.profile.subscription_price_cents} ₸/мес`}
                  </p>
                </>
              )}
              <Link
                href="/dashboard/settings"
                className="btn-outline mt-3 w-full text-sm"
              >
                Редактировать профиль
              </Link>
            </div>
          </aside>

          {/* Posts table */}
          <div className="lg:col-span-2">
            <div className="card overflow-hidden">
              <div className="border-b px-5 py-4 font-semibold">Мои посты</div>
              {!posts || posts.length === 0 ? (
                <div className="px-5 py-12 text-center text-gray-400 text-sm">
                  Постов пока нет. Создайте первый!
                </div>
              ) : (
                <ul className="divide-y">
                  {posts.map((post) => (
                    <li key={post.id} className="flex items-center justify-between gap-3 px-5 py-4">
                      <div className="min-w-0">
                        <Link
                          href={`/posts/${post.id}`}
                          className="block truncate font-medium hover:text-brand-600"
                        >
                          {post.title}
                        </Link>
                        <div className="flex items-center gap-2 mt-0.5 text-xs text-gray-400">
                          <span className={post.is_free ? "text-green-600" : "text-brand-600"}>
                            {post.is_free ? "Бесплатно" : "Платно"}
                          </span>
                          <span>·</span>
                          <span>
                            {formatDistanceToNow(new Date(post.created_at), {
                              addSuffix: true,
                              locale: ru,
                            })}
                          </span>
                        </div>
                      </div>
                      <div className="flex shrink-0 items-center gap-2">
                        {!post.is_published && (
                          <button
                            onClick={() => publishMutation.mutate(post.id)}
                            disabled={publishMutation.isPending}
                            title="Опубликовать"
                            className="btn-ghost p-2 text-green-600"
                          >
                            <Send size={15} />
                          </button>
                        )}
                        <span title={post.is_published ? "Опубликован" : "Черновик"}>
                          {post.is_published ? (
                            <Eye size={15} className="text-gray-400" />
                          ) : (
                            <EyeOff size={15} className="text-gray-300" />
                          )}
                        </span>
                        <Link
                          href={`/dashboard/posts/${post.id}`}
                          className="btn-ghost p-2 text-gray-500"
                          title="Редактировать"
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
          title="Удалить пост?"
          message="Это действие нельзя отменить. Пост будет удалён безвозвратно."
          confirmLabel="Удалить"
          danger
          onConfirm={() => deleteMutation.mutate(deleteTarget)}
          onClose={() => setDeleteTarget(null)}
        />
      )}
    </div>
  );
}
