"use client";

import { useQuery } from "@tanstack/react-query";
import { followingApi } from "@/lib/api";
import { CreatorWithProfile } from "@/lib/types";
import { CreatorCard } from "@/components/creator/CreatorCard";
import { useAuth } from "@/hooks/useAuth";
import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { Heart } from "lucide-react";
import Link from "next/link";

export default function FollowingPage() {
  const { user, isLoading: authLoading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!authLoading && !user) router.push("/register");
  }, [user, authLoading, router]);

  const { data, isLoading } = useQuery({
    queryKey: ["my-following"],
    queryFn: () =>
      followingApi.myFollowing().then((r) => r.data.data as CreatorWithProfile[]),
    enabled: !!user,
  });

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

  return (
    <div className="mx-auto max-w-6xl px-4 py-8">
      <div className="mb-8 flex items-center gap-3">
        <Heart size={24} className="text-brand-600" />
        <h1 className="text-2xl font-bold">Мои подписки</h1>
      </div>

      {!data || data.length === 0 ? (
        <div className="card py-20 text-center">
          <Heart size={40} className="mx-auto mb-4 text-gray-300 dark:text-gray-600" />
          <p className="text-gray-400 mb-4">Вы ещё не следите ни за одним автором</p>
          <Link href="/" className="btn-primary inline-flex">
            Найти авторов
          </Link>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {data.map((creator) => (
            <CreatorCard key={creator.user.id} creator={creator} />
          ))}
        </div>
      )}
    </div>
  );
}
