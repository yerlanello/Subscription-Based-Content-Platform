"use client";

import { useQuery } from "@tanstack/react-query";
import { postsApi } from "@/lib/api";
import { Post } from "@/lib/types";
import { PostCard } from "@/components/post/PostCard";
import { useAuth } from "@/hooks/useAuth";
import { useRouter, usePathname, useSearchParams } from "next/navigation";
import { useEffect } from "react";
import { Rss, Sparkles } from "lucide-react";
import Link from "next/link";
import { useT } from "@/hooks/useT";

type Tab = "subscriptions" | "explore";

function SkeletonList() {
  return (
    <div className="space-y-4">
      {Array.from({ length: 3 }).map((_, i) => (
        <div key={i} className="card p-6 space-y-3">
          <div className="skeleton h-4 w-24" />
          <div className="skeleton h-6 w-3/4" />
          <div className="skeleton h-4 w-full" />
        </div>
      ))}
    </div>
  );
}

export default function FeedPage() {
  const { user, isLoading } = useAuth();
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const t = useT();

  const tab = (searchParams.get("tab") ?? "subscriptions") as Tab;
  const setTab = (next: Tab) => {
    const p = new URLSearchParams(searchParams.toString());
    p.set("tab", next);
    router.replace(`${pathname}?${p.toString()}`);
  };

  useEffect(() => {
    if (!isLoading && !user) router.push("/register");
  }, [user, isLoading, router]);

  const { data: feedData, isLoading: feedLoading } = useQuery({
    queryKey: ["feed"],
    queryFn: () => postsApi.feed({ limit: 20 }).then((r) => r.data.data as Post[]),
    enabled: !!user && tab === "subscriptions",
  });

  const { data: exploreData, isLoading: exploreLoading } = useQuery({
    queryKey: ["explore", !!user],
    // Authenticated users get personalised recommendations; anonymous get random explore
    queryFn: () =>
      user
        ? postsApi.recommended({ limit: 20 }).then((r) => r.data.data as Post[])
        : postsApi.explore({ limit: 20 }).then((r) => r.data.data as Post[]),
    enabled: tab === "explore",
    staleTime: 0,
  });

  if (isLoading || !user) return null;

  const tabs: { id: Tab; label: string; icon: React.ReactNode }[] = [
    { id: "subscriptions", label: t.feed.subscriptions, icon: <Rss size={15} /> },
    { id: "explore",       label: t.feed.explore,       icon: <Sparkles size={15} /> },
  ];

  return (
    <div className="mx-auto max-w-2xl px-4 py-8">
      {/* Tabs */}
      <div className="mb-6 flex gap-1 rounded-xl bg-gray-100 dark:bg-gray-800 p-1">
        {tabs.map(({ id, label, icon }) => (
          <button
            key={id}
            onClick={() => setTab(id)}
            className={`flex flex-1 items-center justify-center gap-2 rounded-lg px-4 py-2 text-sm font-medium transition-colors ${
              tab === id
                ? "bg-white dark:bg-gray-900 text-brand-600 shadow-sm"
                : "text-gray-500 hover:text-gray-700 dark:hover:text-gray-300"
            }`}
          >
            {icon}
            {label}
          </button>
        ))}
      </div>

      {/* Subscriptions feed */}
      {tab === "subscriptions" && (
        feedLoading ? <SkeletonList /> :
        !feedData || feedData.length === 0 ? (
          <div className="card p-12 text-center">
            <Rss size={40} className="mx-auto mb-4 text-gray-300" />
            <p className="font-medium text-gray-500">{t.feed.empty}</p>
            <p className="mt-1 text-sm text-gray-400">{t.feed.emptyHint}</p>
            <Link href="/" className="btn-primary mt-4 inline-flex">
              {t.feed.findAuthors}
            </Link>
          </div>
        ) : (
          <div className="space-y-4">
            {feedData.map((post) => <PostCard key={post.id} post={post} />)}
          </div>
        )
      )}

      {/* Explore feed */}
      {tab === "explore" && (
        exploreLoading ? <SkeletonList /> :
        !exploreData || exploreData.length === 0 ? (
          <div className="card p-12 text-center">
            <Sparkles size={40} className="mx-auto mb-4 text-gray-300" />
            <p className="font-medium text-gray-500">{t.feed.exploreEmpty}</p>
          </div>
        ) : (
          <div className="space-y-4">
            {exploreData.map((post) => <PostCard key={post.id} post={post} />)}
          </div>
        )
      )}
    </div>
  );
}
