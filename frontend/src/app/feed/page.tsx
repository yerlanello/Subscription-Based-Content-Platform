"use client";

import { useQuery } from "@tanstack/react-query";
import { postsApi } from "@/lib/api";
import { Post } from "@/lib/types";
import { PostCard } from "@/components/post/PostCard";
import { useAuth } from "@/hooks/useAuth";
import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { Rss } from "lucide-react";
import Link from "next/link";

export default function FeedPage() {
  const { user, isLoading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!isLoading && !user) router.push("/register");
  }, [user, isLoading, router]);

  const { data, isLoading: feedLoading } = useQuery({
    queryKey: ["feed"],
    queryFn: () => postsApi.feed({ limit: 20 }).then((r) => r.data.data as Post[]),
    enabled: !!user,
  });

  if (isLoading || !user) return null;

  return (
    <div className="mx-auto max-w-2xl px-4 py-8">
      <div className="mb-6 flex items-center gap-2">
        <Rss size={22} className="text-brand-500" />
        <h1 className="text-xl font-bold">Лента</h1>
      </div>

      {feedLoading ? (
        <div className="space-y-4">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="card p-6 space-y-3">
              <div className="skeleton h-4 w-24" />
              <div className="skeleton h-6 w-3/4" />
              <div className="skeleton h-4 w-full" />
            </div>
          ))}
        </div>
      ) : !data || data.length === 0 ? (
        <div className="card p-12 text-center">
          <Rss size={40} className="mx-auto mb-4 text-gray-300" />
          <p className="font-medium text-gray-500">Лента пуста</p>
          <p className="mt-1 text-sm text-gray-400">
            Подпишитесь на авторов чтобы видеть их посты здесь
          </p>
          <Link href="/creators" className="btn-primary mt-4 inline-flex">
            Найти авторов
          </Link>
        </div>
      ) : (
        <div className="space-y-4">
          {data.map((post) => (
            <PostCard key={post.id} post={post} />
          ))}
        </div>
      )}
    </div>
  );
}
