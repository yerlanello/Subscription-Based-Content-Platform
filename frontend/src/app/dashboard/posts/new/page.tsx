"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { postsApi } from "@/lib/api";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { useAuth } from "@/hooks/useAuth";

const schema = z.object({
  title: z.string().min(1, "Заголовок обязателен").max(300),
  content: z.string().optional(),
  is_free: z.boolean(),
  publish_now: z.boolean(),
});

type Form = z.infer<typeof schema>;

export default function NewPostPage() {
  const router = useRouter();
  const { user } = useAuth();
  const [serverError, setServerError] = useState("");

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<Form>({
    resolver: zodResolver(schema),
    defaultValues: { is_free: false, publish_now: true },
  });

  const onSubmit = async (values: Form) => {
    setServerError("");
    try {
      const res = await postsApi.create({
        title: values.title,
        content: values.content || undefined,
        type: "text",
        is_free: values.is_free,
      });
      const post = res.data.data;
      if (values.publish_now) {
        await postsApi.publish(post.id);
      }
      router.push(`/dashboard`);
    } catch {
      setServerError("Не удалось создать пост");
    }
  };

  if (!user) return null;

  return (
    <div className="mx-auto max-w-3xl px-4 py-8">
      <h1 className="mb-6 text-2xl font-bold">Новый пост</h1>

      <form onSubmit={handleSubmit(onSubmit)} className="card p-6 space-y-5">
        <div>
          <label className="mb-1 block text-sm font-medium">Заголовок</label>
          <input className="input" placeholder="О чём этот пост?" {...register("title")} />
          {errors.title && <p className="mt-1 text-xs text-red-500">{errors.title.message}</p>}
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium">Содержание</label>
          <textarea
            className="input min-h-[240px] resize-y"
            placeholder="Напишите что-нибудь..."
            {...register("content")}
          />
        </div>

        <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
          <label className="flex cursor-pointer items-center gap-2 text-sm">
            <input type="checkbox" className="rounded border-gray-300 text-brand-600" {...register("is_free")} />
            Бесплатный пост (виден всем)
          </label>
          <label className="flex cursor-pointer items-center gap-2 text-sm">
            <input type="checkbox" className="rounded border-gray-300 text-brand-600" {...register("publish_now")} />
            Опубликовать сразу
          </label>
        </div>

        {serverError && (
          <div className="rounded-lg bg-red-50 px-4 py-3 text-sm text-red-600">{serverError}</div>
        )}

        <div className="flex gap-3">
          <button type="submit" disabled={isSubmitting} className="btn-primary">
            {isSubmitting ? "Сохраняем..." : "Сохранить"}
          </button>
          <button type="button" onClick={() => router.back()} className="btn-outline">
            Отмена
          </button>
        </div>
      </form>
    </div>
  );
}
