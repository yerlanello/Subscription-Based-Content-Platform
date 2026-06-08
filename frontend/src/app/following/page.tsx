"use client";

import { useQuery } from "@tanstack/react-query";
import { followingApi, usersApi } from "@/lib/api";
import { CreatorWithProfile } from "@/lib/types";
import { CreatorCard } from "@/components/creator/CreatorCard";
import { useAuth } from "@/hooks/useAuth";
import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { Heart, CreditCard } from "lucide-react";
import Link from "next/link";
import { useT } from "@/hooks/useT";

export default function FollowingPage() {
  const { user, isLoading: authLoading } = useAuth();
  const router = useRouter();
  const t = useT();

  useEffect(() => {
    if (!authLoading && !user) router.push("/register");
  }, [user, authLoading, router]);

  const { data: subscriptions, isLoading: subsLoading } = useQuery({
    queryKey: ["my-subscriptions"],
    queryFn: () =>
      usersApi.mySubscriptions().then((r) => r.data.data as CreatorWithProfile[]),
    enabled: !!user,
  });

  const { data: following, isLoading: followLoading } = useQuery({
    queryKey: ["my-following"],
    queryFn: () =>
      followingApi.myFollowing().then((r) => r.data.data as CreatorWithProfile[]),
    enabled: !!user,
  });

  const isLoading = subsLoading || followLoading;

  if (isLoading) {
    return (
      <div className="mx-auto max-w-6xl px-4 py-8">
        <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="card h-64 animate-pulse bg-gray-100 dark:bg-gray-800" />
          ))}
        </div>
      </div>
    );
  }

  const hasSubs = subscriptions && subscriptions.length > 0;
  const hasFollowing = following && following.length > 0;

  return (
    <div className="mx-auto max-w-6xl px-4 py-8">
      <div className="mb-8 flex items-center gap-3">
        <Heart size={24} className="text-brand-600" />
        <h1 className="text-2xl font-bold">{t.following.title}</h1>
      </div>

      {/* Paid subscriptions */}
      <section className="mb-10">
        <div className="mb-4 flex items-center gap-2">
          <CreditCard size={18} className="text-brand-600" />
          <h2 className="text-lg font-semibold">{t.following.paidSection}</h2>
          {hasSubs && (
            <span className="rounded-full bg-brand-100 dark:bg-brand-900/30 text-brand-600 px-2 py-0.5 text-xs font-medium">
              {subscriptions.length}
            </span>
          )}
        </div>

        {hasSubs ? (
          <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {subscriptions.map((creator) => (
              <CreatorCard key={creator.user.id} creator={creator} />
            ))}
          </div>
        ) : (
          <div className="card py-10 text-center text-gray-400">
            <CreditCard size={32} className="mx-auto mb-3 opacity-30" />
            <p className="text-sm">{t.following.emptyPaid}</p>
          </div>
        )}
      </section>

      {/* Following */}
      <section>
        <div className="mb-4 flex items-center gap-2">
          <Heart size={18} className="text-brand-600" />
          <h2 className="text-lg font-semibold">{t.following.followSection}</h2>
          {hasFollowing && (
            <span className="rounded-full bg-brand-100 dark:bg-brand-900/30 text-brand-600 px-2 py-0.5 text-xs font-medium">
              {following.length}
            </span>
          )}
        </div>

        {hasFollowing ? (
          <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {following.map((creator) => (
              <CreatorCard key={creator.user.id} creator={creator} />
            ))}
          </div>
        ) : (
          <div className="card py-10 text-center text-gray-400">
            <Heart size={32} className="mx-auto mb-3 opacity-30" />
            <p className="text-sm mb-4">{t.following.empty}</p>
            <Link href="/" className="btn-primary inline-flex text-sm">
              {t.following.findAuthors}
            </Link>
          </div>
        )}
      </section>
    </div>
  );
}