"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { creatorsApi } from "@/lib/api";
import { CreatorPage, Post } from "@/lib/types";
import { useAuth } from "@/hooks/useAuth";
import { PostCard } from "@/components/post/PostCard";
import { formatPrice } from "@/lib/auth";
import { UserCheck, Heart, CreditCard, Lock } from "lucide-react";
import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";

export default function CreatorProfilePage({
  params,
}: {
  params: { username: string };
}) {
  const { username } = params;
  const { user, isLoading: authLoading } = useAuth();
  const router = useRouter();
  const queryClient = useQueryClient();

  useEffect(() => {
    if (!authLoading && !user) router.push("/register");
  }, [user, authLoading, router]);

  const [showPaymentModal, setShowPaymentModal] = useState(false);

  const { data: creator, isLoading } = useQuery({
    queryKey: ["creator", username],
    queryFn: () =>
      creatorsApi.getByUsername(username).then((r) => r.data.data as CreatorPage),
  });

  const { data: posts } = useQuery({
    queryKey: ["creator-posts", username],
    queryFn: () =>
      creatorsApi.getPosts(username).then((r) => r.data.data as Post[]),
    enabled: !!creator,
  });

  const subscribeMutation = useMutation({
    mutationFn: () =>
      creator!.is_subscribed
        ? creatorsApi.unsubscribe(username)
        : creatorsApi.subscribe(username),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ["creator", username] }),
  });

  const followMutation = useMutation({
    mutationFn: () =>
      creator!.is_following
        ? creatorsApi.unfollow(username)
        : creatorsApi.follow(username),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ["creator", username] }),
  });

  if (isLoading) {
    return (
      <div className="mx-auto max-w-4xl px-4 py-8">
        <div className="h-48 animate-pulse rounded-xl bg-gray-200" />
      </div>
    );
  }

  if (!creator) {
    return (
      <div className="py-20 text-center text-gray-400">Автор не найден</div>
    );
  }

  const isOwnProfile = user?.id === creator.user.id;
  const price = creator.profile.subscription_price_cents;

  return (
    <div className="mx-auto max-w-4xl px-4 py-8">
      {/* Cover + Avatar */}
      <div className="relative mb-16">
        <div className="h-48 overflow-hidden rounded-xl bg-gradient-to-r from-brand-500 to-purple-600">
          {creator.profile.cover_url && (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={creator.profile.cover_url}
              alt="cover"
              className="h-full w-full object-cover"
            />
          )}
        </div>
        {/* Avatar — вне overflow контейнера */}
        <div className="absolute -bottom-12 left-6">
          {creator.user.avatar_url ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={creator.user.avatar_url}
              alt={creator.user.username}
              className="h-24 w-24 rounded-full border-4 border-white object-cover shadow"
            />
          ) : (
            <div className="flex h-24 w-24 items-center justify-center rounded-full border-4 border-white bg-brand-100 text-3xl font-bold text-brand-600 shadow">
              {creator.profile.display_name[0].toUpperCase()}
            </div>
          )}
        </div>
      </div>

      {/* Info */}
      <div className="mb-8 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold">{creator.profile.display_name}</h1>
          <p className="text-gray-500">@{creator.user.username}</p>
          {creator.profile.category && (
            <span className="mt-1 inline-block rounded-full bg-gray-100 px-3 py-0.5 text-xs text-gray-600">
              {creator.profile.category}
            </span>
          )}
          {creator.profile.description && (
            <p className="mt-3 max-w-lg text-gray-700">{creator.profile.description}</p>
          )}
        </div>

        {!isOwnProfile && user && (
          <div className="flex flex-col gap-2 sm:items-end">
            {creator.is_subscribed ? (
              <button
                onClick={() => subscribeMutation.mutate()}
                disabled={subscribeMutation.isPending}
                className="btn-outline min-w-[160px]"
              >
                <UserCheck size={16} />
                Отписаться
              </button>
            ) : (
              <button
                onClick={() => setShowPaymentModal(true)}
                className="btn-primary min-w-[160px]"
              >
                <CreditCard size={16} />
                {price === 0 ? "Подписаться бесплатно" : `Подписаться · ${formatPrice(price)}`}
              </button>
            )}

            {/* Follow */}
            <button
              onClick={() => followMutation.mutate()}
              disabled={followMutation.isPending}
              className="btn-ghost text-sm"
            >
              <Heart
                size={14}
                className={creator.is_following ? "fill-red-500 text-red-500" : ""}
              />
              {creator.is_following ? "Отписан от уведомлений" : "Следить"}
            </button>

            {creator.profile.subscription_description && (
              <p className="mt-1 max-w-xs text-right text-xs text-gray-500">
                {creator.profile.subscription_description}
              </p>
            )}
          </div>
        )}
      </div>

      {/* Payment Modal */}
      {showPaymentModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 px-4">
          <div className="card w-full max-w-md p-6">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-lg font-semibold">Оформить подписку</h2>
              <button onClick={() => setShowPaymentModal(false)} className="btn-ghost p-1 text-gray-400">✕</button>
            </div>
            <div className="mb-6 rounded-xl bg-gray-50 p-4 text-center">
              <p className="text-2xl font-bold text-brand-600">{formatPrice(price)}</p>
              <p className="text-sm text-gray-500">в месяц</p>
              {creator.profile.subscription_description && (
                <p className="mt-2 text-sm text-gray-600">{creator.profile.subscription_description}</p>
              )}
            </div>
            <div className="flex items-center gap-3 rounded-lg border border-dashed border-gray-300 bg-gray-50 p-4">
              <Lock size={20} className="shrink-0 text-gray-400" />
              <div>
                <p className="text-sm font-medium text-gray-700">Оплата пока недоступна</p>
                <p className="text-xs text-gray-400">Система оплаты находится в разработке. Скоро появится возможность оплаты картой.</p>
              </div>
            </div>
            <button onClick={() => setShowPaymentModal(false)} className="btn-outline mt-4 w-full">
              Закрыть
            </button>
          </div>
        </div>
      )}

      {/* Posts */}
      <h2 className="mb-4 text-lg font-semibold">Посты</h2>
      {!posts || posts.length === 0 ? (
        <div className="card p-12 text-center text-gray-400">Постов пока нет</div>
      ) : (
        <div className="space-y-4">
          {posts.map((post) => (
            <PostCard key={post.id} post={post} />
          ))}
        </div>
      )}
    </div>
  );
}
