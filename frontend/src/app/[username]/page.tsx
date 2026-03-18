"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { creatorsApi } from "@/lib/api";
import { CreatorPage, Post } from "@/lib/types";
import { useAuth } from "@/hooks/useAuth";
import { PostCard } from "@/components/post/PostCard";
import { formatPrice } from "@/lib/auth";
import { UserCheck, Heart } from "lucide-react";
import { use } from "react";

export default function CreatorProfilePage({
  params,
}: {
  params: Promise<{ username: string }>;
}) {
  const { username } = use(params);
  const { user } = useAuth();
  const queryClient = useQueryClient();

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
      {/* Cover */}
      <div className="relative mb-16 h-48 overflow-hidden rounded-xl bg-gradient-to-r from-brand-500 to-purple-600">
        {creator.profile.cover_url && (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={creator.profile.cover_url}
            alt="cover"
            className="h-full w-full object-cover"
          />
        )}
        {/* Avatar */}
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
            {/* Subscribe */}
            <button
              onClick={() => subscribeMutation.mutate()}
              disabled={subscribeMutation.isPending}
              className={`btn min-w-[160px] ${
                creator.is_subscribed ? "btn-outline" : "btn-primary"
              }`}
            >
              <UserCheck size={16} />
              {creator.is_subscribed
                ? "Отписаться"
                : price === 0
                ? "Подписаться бесплатно"
                : `Подписаться · ${formatPrice(price)}`}
            </button>

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

            {/* Subscription description */}
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
    </div>
  );
}
