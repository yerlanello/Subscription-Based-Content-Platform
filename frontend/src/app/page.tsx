"use client";

import { useQuery } from "@tanstack/react-query";
import { creatorsApi } from "@/lib/api";
import { CreatorCard } from "@/components/creator/CreatorCard";
import { CreatorWithProfile } from "@/lib/types";
import { Search } from "lucide-react";
import { useState } from "react";
import { useAuth } from "@/hooks/useAuth";
import { LandingPage } from "@/components/layout/LandingPage";
import { useT } from "@/hooks/useT";

const DB_CATEGORIES = ["Музыка", "Искусство", "Подкасты", "Игры", "Образование", "Другое"];

export default function HomePage() {
  const { user, isLoading: authLoading } = useAuth();
  const t = useT();
  const [category, setCategory] = useState<string | undefined>();
  const [search, setSearch] = useState("");

  const { data, isLoading } = useQuery({
    queryKey: ["creators", category],
    queryFn: () => creatorsApi.list({ limit: 24, category }).then((r) => r.data.data as CreatorWithProfile[]),
    enabled: !!user,
  });

  const filtered = (data ?? []).filter((c) =>
    c.profile.display_name.toLowerCase().includes(search.toLowerCase())
  );

  if (authLoading) return null;
  if (!user) return <LandingPage />;

  return (
    <div className="mx-auto max-w-6xl px-4 py-8">
      <div className="mb-10 text-center">
        <h1 className="text-4xl font-bold text-gray-900 dark:text-gray-100">
          {t.home.title}
        </h1>
        <p className="mt-3 text-lg text-gray-500 dark:text-gray-400">
          {t.home.subtitle}
        </p>
      </div>

      <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={16} />
          <input
            className="input pl-9"
            placeholder={t.home.searchPlaceholder}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
        <div className="flex flex-wrap gap-2">
          <button
            onClick={() => setCategory(undefined)}
            className={`rounded-full px-3 py-1 text-sm font-medium transition-colors ${
              !category
                ? "bg-brand-600 text-white"
                : "bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700"
            }`}
          >
            {t.home.all}
          </button>
          {DB_CATEGORIES.map((cat) => (
            <button
              key={cat}
              onClick={() => setCategory(cat === category ? undefined : cat)}
              className={`rounded-full px-3 py-1 text-sm font-medium transition-colors ${
                category === cat
                  ? "bg-brand-600 text-white"
                  : "bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700"
              }`}
            >
              {t.categoryLabels[cat] ?? cat}
            </button>
          ))}
        </div>
      </div>

      {isLoading ? (
        <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="card h-64 animate-pulse bg-gray-100 dark:bg-gray-800" />
          ))}
        </div>
      ) : filtered.length === 0 ? (
        <div className="py-20 text-center text-gray-400">{t.home.notFound}</div>
      ) : (
        <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {filtered.map((creator) => (
            <CreatorCard key={creator.user.id} creator={creator} />
          ))}
        </div>
      )}
    </div>
  );
}
