"use client";

import { useQuery } from "@tanstack/react-query";
import { postsApi } from "@/lib/api";
import { Post } from "@/lib/types";
import { PostCard } from "@/components/post/PostCard";
import { useAuth } from "@/hooks/useAuth";
import { useRouter } from "next/navigation";
import { useEffect } from "react";

export default function FeedPage() {
  const { user, isLoading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!isLoading && !user) router.push("/login");
  }, [user, isLoading, router]);

  const { data, isLoading: feedLoading } = useQuery({
    queryKey: ["feed"],
    queryFn: () => postsApi.feed({ limit: 20 }).then((r) => r.data.data as Post[]),
    enabled: !!user,
  });

  if (isLoading || !user) return null;

  return (
    <div className="mx-auto max-w-2xl px-4 py-8">
      <h1 className="mb-6 text-2xl font-bold">Лента</h1>

      {feedLoading ? (
        <div className="space-y-4">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="card h-48 animate-pulse bg-gray-100" />
          ))}
        </div>
      ) : !data || data.length === 0 ? (
        <div className="card p-12 text-center">
          <p className="text-gray-500">Лента пуста.</p>
          <p className="mt-1 text-sm text-gray-400">
            Подпишитесь на авторов чтобы видеть их посты здесь.
          </p>
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
