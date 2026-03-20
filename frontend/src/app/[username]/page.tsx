"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { creatorsApi } from "@/lib/api";
import { CreatorPage, Post } from "@/lib/types";
import { useAuth } from "@/hooks/useAuth";
import { PostCard } from "@/components/post/PostCard";
import { formatPrice } from "@/lib/auth";
import { UserCheck, Heart, CreditCard, AlertTriangle } from "lucide-react";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ConfirmModal } from "@/components/ui/ConfirmModal";

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

  const [subscribeError, setSubscribeError] = useState<string | null>(null);
  const [showUnsubscribeModal, setShowUnsubscribeModal] = useState(false);

  const subscribeMutation = useMutation({
    mutationFn: async () => {
      setSubscribeError(null);
      if (creator!.is_subscribed) {
        return creatorsApi.unsubscribe(username);
      }
      // Платная подписка — редирект на Stripe
      if (creator!.profile.subscription_price_cents > 0) {
        const res = await creatorsApi.createCheckout(username);
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const url = (res.data as any)?.data?.url ?? (res.data as any)?.url;
        if (!url) throw new Error("Не удалось получить ссылку на оплату");
        window.location.href = url;
        return;
      }
      // Бесплатная подписка — сразу
      return creatorsApi.subscribe(username);
    },
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ["creator", username] }),
    onError: (err: unknown) => {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const msg = (err as any)?.response?.data?.error ?? (err as any)?.message ?? "Ошибка при оформлении подписки";
      setSubscribeError(msg);
    },
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
                onClick={() => setShowUnsubscribeModal(true)}
                disabled={subscribeMutation.isPending}
                className="btn-outline min-w-[160px]"
              >
                <UserCheck size={16} />
                {subscribeMutation.isPending ? "Загрузка..." : "Отписаться"}
              </button>
            ) : (
              <button
                onClick={() => subscribeMutation.mutate()}
                disabled={subscribeMutation.isPending}
                className="btn-primary min-w-[160px]"
              >
                <CreditCard size={16} />
                {subscribeMutation.isPending
                  ? "Загрузка..."
                  : price === 0
                  ? "Подписаться бесплатно"
                  : `Подписаться · ${formatPrice(price)}`}
              </button>
            )}

            {subscribeError && (
              <p className="text-xs text-red-500 max-w-[200px] text-right">{subscribeError}</p>
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

      {showUnsubscribeModal && (
        <ConfirmModal
          title="Отписаться от автора?"
          message={
            <div className="space-y-3">
              <div className="flex items-start gap-2 rounded-lg bg-amber-50 p-3 text-amber-800">
                <AlertTriangle size={16} className="mt-0.5 shrink-0" />
                <span>Денежные средства за текущий период не возвращаются.</span>
              </div>
              <p>Вы потеряете доступ ко всем платным постам <strong>{creator.profile.display_name}</strong>.</p>
              <p className="text-gray-400 text-xs">Автор будет скучать. Может, просто пауза? 🥺</p>
            </div>
          }
          confirmLabel="Всё равно отписаться"
          cancelLabel="Остаться"
          danger
          onConfirm={() => subscribeMutation.mutate()}
          onClose={() => setShowUnsubscribeModal(false)}
        />
      )}
    </div>
  );
}
