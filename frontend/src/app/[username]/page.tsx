"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { creatorsApi } from "@/lib/api";
import { CreatorPage, Post } from "@/lib/types";
import { useAuth } from "@/hooks/useAuth";
import { PostCard } from "@/components/post/PostCard";
import { formatPrice } from "@/lib/auth";
import { UserCheck, Heart, CreditCard, AlertTriangle, Gift, Users, BookOpen, Calendar, Pin } from "lucide-react";
import { useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { ConfirmModal } from "@/components/ui/ConfirmModal";
import { DonateModal } from "@/components/creator/DonateModal";
import { useT } from "@/hooks/useT";
import { useLocaleStore } from "@/store/localeStore";
import { format } from "date-fns";
import { ru as ruLocale, enUS, kk as kkLocale } from "date-fns/locale";
import type { Locale } from "date-fns";

const dateFnsLocales: Record<string, Locale> = { ru: ruLocale, en: enUS, kk: kkLocale };

function formatDate(iso: string, locale: Locale) {
  return format(new Date(iso), "d MMMM yyyy", { locale });
}

export default function CreatorProfilePage({
  params,
}: {
  params: { username: string };
}) {
  const { username } = params;
  const { user, isLoading: authLoading } = useAuth();
  const router = useRouter();
  const queryClient = useQueryClient();
  const t = useT();
  const locale = useLocaleStore((s) => s.locale);
  const dateLocale = dateFnsLocales[locale] ?? ruLocale;

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

  const searchParams = useSearchParams();
  const [subscribeError, setSubscribeError] = useState<string | null>(null);
  const [showUnsubscribeModal, setShowUnsubscribeModal] = useState(false);
  const [showDonateModal, setShowDonateModal] = useState(false);
  const [donateSuccess, setDonateSuccess] = useState(false);

  // Verify donation with backend after Stripe redirect
  useEffect(() => {
    const sessionId = searchParams.get("session_id");
    const donated = searchParams.get("donated");
    if (donated === "1" && sessionId) {
      import("@/lib/api").then(({ donationsApi }) => {
        donationsApi.verify(sessionId).catch(() => {}).finally(() => {
          setDonateSuccess(true);
        });
      });
    }
  }, [searchParams]);

  const subscribeMutation = useMutation({
    mutationFn: async () => {
      setSubscribeError(null);
      if (creator!.is_subscribed) {
        return creatorsApi.unsubscribe(username);
      }
      if (creator!.profile.subscription_price_cents > 0) {
        const res = await creatorsApi.createCheckout(username);
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const url = (res.data as any)?.data?.url ?? (res.data as any)?.url;
        if (!url) throw new Error("Не удалось получить ссылку на оплату");
        window.location.href = url;
        return;
      }
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
        <div className="h-48 animate-pulse rounded-xl bg-gray-200 dark:bg-gray-800" />
      </div>
    );
  }

  if (!creator) {
    return (
      <div className="py-20 text-center text-gray-400">{t.creator.notFound}</div>
    );
  }

  const isOwnProfile = user?.id === creator.user.id;
  const price = creator.profile.subscription_price_cents;

  return (
    <div className="mx-auto max-w-4xl px-4 py-8">
      {/* Cover + Avatar */}
      <div className="relative mb-16">
        <div className="h-48 overflow-hidden rounded-xl bg-gradient-to-r from-brand-500 to-purple-600 dark:from-brand-700 dark:to-purple-800">
          {creator.profile.cover_url && (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={creator.profile.cover_url}
              alt="cover"
              className="h-48 w-full object-cover block"
            />
          )}
        </div>
        <div className="absolute -bottom-12 left-6">
          {creator.user.avatar_url ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={creator.user.avatar_url}
              alt={creator.user.username}
              className="h-24 w-24 rounded-full border-4 border-white dark:border-gray-900 object-cover shadow"
            />
          ) : (
            <div className="flex h-24 w-24 items-center justify-center rounded-full border-4 border-white dark:border-gray-900 bg-brand-100 text-3xl font-bold text-brand-600 shadow">
              {creator.profile.display_name[0].toUpperCase()}
            </div>
          )}
        </div>
      </div>

      {/* Info */}
      <div className="mb-8 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold">{creator.profile.display_name}</h1>
          <p className="text-gray-500 dark:text-gray-400">@{creator.user.username}</p>
          {creator.profile.category && (
            <span className="mt-1 inline-block rounded-full bg-gray-100 dark:bg-gray-800 px-3 py-0.5 text-xs text-gray-600 dark:text-gray-400">
              {creator.profile.category}
            </span>
          )}

          {/* Счётчики и дата */}
          <div className="mt-3 flex flex-wrap items-center gap-4 text-sm text-gray-500 dark:text-gray-400">
            <span className="flex items-center gap-1.5">
              <Users size={14} className="text-brand-500" />
              <strong className="text-gray-900 dark:text-gray-100">{creator.subscriber_count ?? 0}</strong>
              {t.creator.subscribers}
            </span>
            <span className="flex items-center gap-1.5">
              <BookOpen size={14} className="text-brand-500" />
              <strong className="text-gray-900 dark:text-gray-100">{creator.follower_count ?? 0}</strong>
              {t.creator.followers}
            </span>
            <span className="flex items-center gap-1.5">
              <Calendar size={14} />
              {t.creator.memberSince} {formatDate(creator.user.created_at, dateLocale)}
            </span>
          </div>

          {creator.profile.description && (
            <p className="mt-3 max-w-lg text-gray-700 dark:text-gray-300">{creator.profile.description}</p>
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
                {subscribeMutation.isPending ? t.creator.loading : t.creator.unsubscribe}
              </button>
            ) : (
              <button
                onClick={() => subscribeMutation.mutate()}
                disabled={subscribeMutation.isPending}
                className="btn-primary min-w-[160px]"
              >
                <CreditCard size={16} />
                {subscribeMutation.isPending
                  ? t.creator.loading
                  : price === 0
                  ? t.creator.subscribeFree
                  : `${t.creator.subscribe} · ${formatPrice(price, t.billing.perMonth)}`}
              </button>
            )}

            {subscribeError && (
              <p className="text-xs text-red-500 max-w-[200px] text-right">{subscribeError}</p>
            )}

            <button
              onClick={() => setShowDonateModal(true)}
              className="btn-outline text-sm min-w-[160px]"
            >
              <Gift size={16} />
              {t.creator.donate}
            </button>

            <button
              onClick={() => followMutation.mutate()}
              disabled={followMutation.isPending}
              className="btn-ghost text-sm"
            >
              <Heart
                size={14}
                className={creator.is_following ? "fill-red-500 text-red-500" : ""}
              />
              {creator.is_following ? t.creator.unfollow : t.creator.follow}
            </button>

            {creator.profile.subscription_description && (
              <p className="mt-1 max-w-xs text-right text-xs text-gray-500 dark:text-gray-400">
                {creator.profile.subscription_description}
              </p>
            )}
          </div>
        )}
      </div>

      {/* Posts */}
      <h2 className="mb-4 text-lg font-semibold">{t.creator.posts}</h2>
      {!posts || posts.length === 0 ? (
        <div className="card p-12 text-center text-gray-400">{t.creator.noPosts}</div>
      ) : (
        <div className="space-y-4">
          {posts.map((post) => (
            <div key={post.id} className="relative">
              {post.is_pinned && (
                <div className="flex items-center gap-1.5 mb-1 text-xs text-brand-500 font-medium px-1">
                  <Pin size={12} />
                  {t.post.pinned}
                </div>
              )}
              <PostCard post={post} />
            </div>
          ))}
        </div>
      )}

      {donateSuccess && (
        <div className="fixed bottom-6 right-6 z-50 flex items-center gap-3 rounded-xl bg-green-600 px-5 py-3 text-white shadow-lg">
          <Gift size={18} />
          <span className="font-medium">{t.creator.donateSuccess} 🎉</span>
          <button onClick={() => setDonateSuccess(false)} className="ml-2 opacity-70 hover:opacity-100">
            ×
          </button>
        </div>
      )}

      {showDonateModal && (
        <DonateModal
          username={username}
          displayName={creator.profile.display_name}
          onClose={() => setShowDonateModal(false)}
        />
      )}

      {showUnsubscribeModal && (
        <ConfirmModal
          title={t.creator.unsubscribeTitle}
          message={
            <div className="space-y-3">
              <div className="flex items-start gap-2 rounded-lg bg-amber-50 p-3 text-amber-800">
                <AlertTriangle size={16} className="mt-0.5 shrink-0" />
                <span>{t.creator.unsubscribeWarning}</span>
              </div>
              <p>{t.creator.unsubscribeAccess} <strong>{creator.profile.display_name}</strong>.</p>
              <p className="text-gray-400 text-xs">{t.creator.unsubscribeHint}</p>
            </div>
          }
          confirmLabel={t.creator.unsubscribeConfirm}
          cancelLabel={t.creator.unsubscribeCancel}
          danger
          onConfirm={() => subscribeMutation.mutate()}
          onClose={() => setShowUnsubscribeModal(false)}
        />
      )}
    </div>
  );
}
