"use client";

import { useAuth } from "@/hooks/useAuth";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { creatorsApi, postsApi, usersApi } from "@/lib/api";
import { CreatorPage, Post } from "@/lib/types";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import Link from "next/link";
import { formatDistanceToNow } from "date-fns";
import { ru } from "date-fns/locale";
import { LayoutDashboard, PlusCircle, Eye, EyeOff, Settings } from "lucide-react";
import { BecomeCreatorModal } from "@/components/creator/BecomeCreatorModal";
import { formatPrice } from "@/lib/auth";

export default function ProfilePage() {
  const { user, isLoading } = useAuth();
  const router = useRouter();
  const [showModal, setShowModal] = useState(false);
  const [avatarUploading, setAvatarUploading] = useState(false);
  const queryClient = useQueryClient();

  const handleAvatarChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setAvatarUploading(true);
    try {
      const formData = new FormData();
      formData.append("avatar", file);
      const res = await usersApi.uploadAvatar(formData);
      const avatarUrl: string = res.data.data.avatar_url;
      await usersApi.updateMe({ avatar_url: avatarUrl });
      queryClient.invalidateQueries({ queryKey: ["me"] });
    } catch {
      alert("Не удалось загрузить аватар");
    } finally {
      setAvatarUploading(false);
      e.target.value = "";
    }
  };

  useEffect(() => {
    if (!isLoading && !user) router.push("/login");
  }, [user, isLoading, router]);

  const isCreator = user?.role === "creator" || user?.role === "both";

  const { data: creator } = useQuery({
    queryKey: ["my-creator", user?.username],
    queryFn: () =>
      creatorsApi.getByUsername(user!.username).then((r) => r.data.data as CreatorPage),
    enabled: !!user && isCreator,
  });

  const { data: posts } = useQuery({
    queryKey: ["my-posts", user?.username],
    queryFn: () =>
      creatorsApi.getPosts(user!.username, { limit: 10 }).then((r) => r.data.data as Post[]),
    enabled: !!user && isCreator,
  });

  if (isLoading || !user) return null;

  return (
    <div className="mx-auto max-w-4xl px-4 py-8">
      {/* Шапка профиля */}
      <div className="card mb-6">
        {/* Cover */}
        <div className="h-36 overflow-hidden rounded-t-2xl bg-gradient-to-r from-brand-500 to-purple-600">
          {creator?.profile.cover_url && (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={creator.profile.cover_url} alt="" className="h-full w-full object-cover" />
          )}
        </div>

        <div className="px-6 pb-6">
          {/* Avatar row */}
          <div className="flex items-end justify-between -mt-10 mb-4">
            <div className="relative">
              {user.avatar_url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={user.avatar_url}
                  alt={user.username}
                  className="h-20 w-20 rounded-full border-4 border-white object-cover shadow"
                />
              ) : (
                <div className="flex h-20 w-20 items-center justify-center rounded-full border-4 border-white bg-brand-100 text-2xl font-bold text-brand-600 shadow">
                  {user.username[0].toUpperCase()}
                </div>
              )}
              <button
                onClick={() => document.getElementById("avatar-input")?.click()}
                className="absolute bottom-0 right-0 flex h-6 w-6 items-center justify-center rounded-full bg-brand-600 text-white shadow hover:bg-brand-700"
                title="Сменить аватар"
              >
                <Settings size={12} />
              </button>
              <input
                id="avatar-input"
                type="file"
                accept="image/*"
                className="hidden"
                onChange={handleAvatarChange}
              />
            </div>

            {isCreator && (
              <div className="flex gap-2">
                <Link href="/dashboard" className="btn-outline text-sm">
                  <LayoutDashboard size={14} />
                  Кабинет
                </Link>
                <Link href="/dashboard/settings" className="btn-ghost text-sm">
                  <Settings size={14} />
                </Link>
              </div>
            )}
          </div>

          {/* Info */}
          <h1 className="text-xl font-bold">{creator?.profile.display_name ?? user.username}</h1>
          <p className="text-sm text-gray-500">@{user.username}</p>
          {user.bio && <p className="mt-2 text-gray-600">{user.bio}</p>}
          {creator?.profile.category && (
            <span className="mt-2 inline-block rounded-full bg-gray-100 px-3 py-0.5 text-xs text-gray-500">
              {creator.profile.category}
            </span>
          )}
          {isCreator && creator?.profile.subscription_price_cents !== undefined && (
            <p className="mt-2 text-sm font-medium text-brand-600">
              {creator.profile.subscription_price_cents === 0
                ? "Бесплатная подписка"
                : `${formatPrice(creator.profile.subscription_price_cents)} / мес`}
            </p>
          )}
        </div>
      </div>

      {/* Не автор — предложение стать автором */}
      {!isCreator && (
        <div className="card flex flex-col items-center gap-4 py-14 text-center">
          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-brand-50">
            <PlusCircle size={28} className="text-brand-500" />
          </div>
          <div>
            <p className="text-lg font-semibold">Станьте автором</p>
            <p className="mt-1 text-sm text-gray-500">
              Создайте профиль автора, публикуйте контент и получайте поддержку подписчиков
            </p>
          </div>
          <button onClick={() => setShowModal(true)} className="btn-primary">
            Стать автором
          </button>
        </div>
      )}

      {/* Автор — последние посты */}
      {isCreator && (
        <div className="card overflow-hidden">
          <div className="flex items-center justify-between border-b px-5 py-4">
            <h2 className="font-semibold">Мои посты</h2>
            <Link href="/dashboard/posts/new" className="btn-primary text-sm">
              <PlusCircle size={14} />
              Новый пост
            </Link>
          </div>

          {!posts || posts.length === 0 ? (
            <div className="px-5 py-12 text-center text-sm text-gray-400">
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
                      <span className={post.is_free ? "text-green-600" : "text-brand-500"}>
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
                  <span title={post.is_published ? "Опубликован" : "Черновик"}>
                    {post.is_published ? (
                      <Eye size={15} className="text-gray-400" />
                    ) : (
                      <EyeOff size={15} className="text-gray-300" />
                    )}
                  </span>
                </li>
              ))}
            </ul>
          )}

          {posts && posts.length > 0 && (
            <div className="border-t px-5 py-3 text-center">
              <Link href="/dashboard" className="text-sm text-brand-600 hover:underline">
                Все посты в кабинете →
              </Link>
            </div>
          )}
        </div>
      )}

      {showModal && <BecomeCreatorModal onClose={() => setShowModal(false)} />}
    </div>
  );
}
