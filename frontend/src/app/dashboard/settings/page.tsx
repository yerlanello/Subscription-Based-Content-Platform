"use client";

import { useForm } from "react-hook-form";
import { creatorsApi } from "@/lib/api";
import { useAuth } from "@/hooks/useAuth";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { CreatorPage } from "@/lib/types";
import { useEffect } from "react";
import { useRouter } from "next/navigation";

export default function DashboardSettingsPage() {
  const { user } = useAuth();
  const router = useRouter();
  const queryClient = useQueryClient();

  const { data: creator } = useQuery({
    queryKey: ["my-creator"],
    queryFn: () =>
      creatorsApi.getByUsername(user!.username).then((r) => r.data.data as CreatorPage),
    enabled: !!user,
  });

  const { register, handleSubmit, reset } = useForm({
    defaultValues: {
      display_name: "",
      description: "",
      category: "",
      subscription_price_cents: 0,
      subscription_description: "",
    },
  });

  useEffect(() => {
    if (creator?.profile) {
      reset({
        display_name: creator.profile.display_name,
        description: creator.profile.description ?? "",
        category: creator.profile.category ?? "",
        subscription_price_cents: creator.profile.subscription_price_cents,
        subscription_description: creator.profile.subscription_description ?? "",
      });
    }
  }, [creator, reset]);

  const mutation = useMutation({
    mutationFn: (data: Record<string, unknown>) =>
      creatorsApi.updateProfile(user!.username, data as Parameters<typeof creatorsApi.updateProfile>[1]),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["my-creator"] });
      router.push("/dashboard");
    },
  });

  if (!user) return null;

  return (
    <div className="mx-auto max-w-2xl px-4 py-8">
      <h1 className="mb-6 text-2xl font-bold">Настройки профиля</h1>

      <form
        onSubmit={handleSubmit((v) => mutation.mutate({
          ...v,
          subscription_price_cents: Number(v.subscription_price_cents),
        }))}
        className="card p-6 space-y-5"
      >
        <div>
          <label className="mb-1 block text-sm font-medium">Отображаемое имя</label>
          <input className="input" {...register("display_name")} />
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium">О себе</label>
          <textarea className="input min-h-[100px] resize-y" {...register("description")} />
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium">Категория</label>
          <select className="input" {...register("category")}>
            <option value="">Выберите категорию</option>
            {["Музыка", "Искусство", "Подкасты", "Игры", "Образование", "Другое"].map((c) => (
              <option key={c} value={c}>{c}</option>
            ))}
          </select>
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium">
            Цена подписки (₸/мес, 0 = бесплатно)
          </label>
          <div className="relative">
            <input
              className="input pr-10"
              type="number"
              min={0}
              step={100}
              placeholder="0"
              {...register("subscription_price_cents")}
            />
            <span className="absolute right-3 top-1/2 -translate-y-1/2 text-sm text-gray-400">₸</span>
          </div>
          <p className="mt-1 text-xs text-gray-400">Пример: 500 ₸/мес</p>
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium">Что получит подписчик</label>
          <textarea className="input min-h-[80px] resize-y" {...register("subscription_description")} />
        </div>

        <div className="flex gap-3">
          <button type="submit" disabled={mutation.isPending} className="btn-primary">
            {mutation.isPending ? "Сохраняем..." : "Сохранить"}
          </button>
          <button type="button" onClick={() => router.back()} className="btn-outline">
            Отмена
          </button>
        </div>
      </form>
    </div>
  );
}
