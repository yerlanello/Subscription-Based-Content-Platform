"use client";

import { useForm } from "react-hook-form";
import { creatorsApi } from "@/lib/api";
import { useAuth } from "@/hooks/useAuth";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { CreatorPage } from "@/lib/types";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { useT } from "@/hooks/useT";
import { ImagePlus } from "lucide-react";

export default function DashboardSettingsPage() {
  const { user } = useAuth();
  const router = useRouter();
  const queryClient = useQueryClient();
  const t = useT();

  const { data: creator } = useQuery({
    queryKey: ["my-creator"],
    queryFn: () =>
      creatorsApi.getByUsername(user!.username).then((r) => r.data.data as CreatorPage),
    enabled: !!user,
  });

  const { register, handleSubmit, reset, setValue } = useForm({
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

  const coverInputRef = useRef<HTMLInputElement>(null);
  const [coverPreview, setCoverPreview] = useState<string | null>(null);

  const coverMutation = useMutation({
    mutationFn: (file: File) => {
      const fd = new FormData();
      fd.append("cover", file);
      return creatorsApi.uploadCover(user!.username, fd);
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["my-creator"] }),
  });

  const mutation = useMutation({
    mutationFn: (data: Record<string, unknown>) =>
      creatorsApi.updateProfile(user!.username, data as Parameters<typeof creatorsApi.updateProfile>[1]),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["my-creator"] });
      router.push("/dashboard");
    },
  });

  if (!user) return null;

  const categories = ["Музыка", "Искусство", "Подкасты", "Игры", "Образование", "Другое"];

  return (
    <div className="mx-auto max-w-2xl px-4 py-8">
      <h1 className="mb-6 text-2xl font-bold">{t.settings.title}</h1>

      {/* Cover upload */}
      <div className="mb-6 card overflow-hidden">
        <div
          className="relative h-36 cursor-pointer group bg-gradient-to-r from-brand-500 to-purple-600"
          onClick={() => coverInputRef.current?.click()}
        >
          {(coverPreview || creator?.profile.cover_url) && (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={coverPreview ?? creator!.profile.cover_url!}
              alt="cover"
              className="h-36 w-full object-cover block"
            />
          )}
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-1 bg-black/30 opacity-0 group-hover:opacity-100 transition-opacity text-white">
            <ImagePlus size={24} />
            <span className="text-sm font-medium">
              {coverMutation.isPending ? t.settings.uploadingCover : t.settings.uploadCover}
            </span>
          </div>
        </div>
        <input
          ref={coverInputRef}
          type="file"
          accept=".jpg,.jpeg,.png,.webp"
          className="hidden"
          onChange={(e) => {
            const file = e.target.files?.[0];
            if (!file) return;
            setCoverPreview(URL.createObjectURL(file));
            coverMutation.mutate(file);
          }}
        />
        <div className="px-4 py-2 text-xs text-gray-400">{t.settings.coverImage} — JPG, PNG, WebP</div>
      </div>

      <form
        onSubmit={handleSubmit((v) => mutation.mutate({
          ...v,
          subscription_price_cents: Number(v.subscription_price_cents),
        }))}
        className="card p-6 space-y-5"
      >
        <div>
          <label className="mb-1 block text-sm font-medium">{t.settings.displayName}</label>
          <input className="input" {...register("display_name")} />
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium">{t.settings.about}</label>
          <textarea className="input min-h-[100px] resize-y" {...register("description")} />
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium">{t.settings.category}</label>
          <select className="input" {...register("category")}>
            <option value="">{t.settings.chooseCategory}</option>
            {categories.map((c) => (
              <option key={c} value={c}>{t.categoryLabels[c] ?? c}</option>
            ))}
          </select>
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium">
            {t.settings.subscriptionPrice}
          </label>
          <div className="relative">
            <input
              className="input pr-10"
              type="number"
              min={0}
              max={9999999}
              step={100}
              placeholder="0"
              {...register("subscription_price_cents")}
              onFocus={(e) => e.target.select()}
              onChange={(e) => {
                const val = parseInt(e.target.value, 10);
                setValue("subscription_price_cents", isNaN(val) ? 0 : val);
              }}
            />
            <span className="absolute right-3 top-1/2 -translate-y-1/2 text-sm text-gray-400">₸</span>
          </div>
          <p className="mt-1 text-xs text-gray-400">{t.settings.subscriptionPriceHint}</p>
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium">{t.settings.subscriptionBenefits}</label>
          <textarea className="input min-h-[80px] resize-y" {...register("subscription_description")} />
        </div>

        <div className="flex gap-3">
          <button type="submit" disabled={mutation.isPending} className="btn-primary">
            {mutation.isPending ? t.settings.saving : t.common.save}
          </button>
          <button type="button" onClick={() => router.back()} className="btn-outline">
            {t.common.cancel}
          </button>
        </div>
      </form>
    </div>
  );
}
