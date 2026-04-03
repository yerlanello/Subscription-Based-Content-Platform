"use client";

import { useEffect, useState } from "react";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { postsApi } from "@/lib/api";
import { Post, PostAttachment } from "@/lib/types";
import { useRouter } from "next/navigation";
import { useAuth } from "@/hooks/useAuth";
import { useQueryClient } from "@tanstack/react-query";
import { FileUploader } from "@/components/post/FileUploader";
import { Eye, EyeOff, Send } from "lucide-react";
import { useT } from "@/hooks/useT";
import { RichTextEditor } from "@/components/post/RichTextEditor";

const schema = z.object({
  title: z.string().min(1).max(300),
  content: z.string().optional(),
  is_free: z.boolean(),
});
type Form = z.infer<typeof schema>;

export default function EditPostPage({ params }: { params: { id: string } }) {
  const { id } = params;
  const router = useRouter();
  const { user } = useAuth();
  const queryClient = useQueryClient();
  const t = useT();
  const [post, setPost] = useState<Post | null>(null);
  const [attachments, setAttachments] = useState<PostAttachment[]>([]);
  const [serverError, setServerError] = useState("");
  const [loading, setLoading] = useState(true);

  const { register, handleSubmit, reset, control, formState: { errors, isSubmitting } } = useForm<Form>({
    resolver: zodResolver(schema),
  });

  useEffect(() => {
    if (!user) return;
    postsApi.get(id).then((r) => {
      const p = r.data.data as Post;
      setPost(p);
      setAttachments(p.attachments ?? []);
      reset({ title: p.title, content: p.content ?? "", is_free: p.is_free });
    }).catch(() => router.push("/dashboard")).finally(() => setLoading(false));
  }, [id, user, reset, router]);

  const onSubmit = async (values: Form) => {
    setServerError("");
    try {
      await postsApi.update(id, {
        title: values.title,
        content: values.content || undefined,
        is_free: values.is_free,
      });
      await queryClient.invalidateQueries({ queryKey: ["my-posts"] });
      await queryClient.invalidateQueries({ queryKey: ["post", id] });
      router.push("/dashboard");
    } catch {
      setServerError(t.postEditor.saveError);
    }
  };

  const togglePublish = async () => {
    if (!post) return;
    try {
      const res = post.is_published
        ? await postsApi.unpublish(id)
        : await postsApi.publish(id);
      setPost(res.data.data as Post);
      await queryClient.invalidateQueries({ queryKey: ["my-posts"] });
    } catch {
      setServerError(t.postEditor.unpublishError);
    }
  };

  if (loading) {
    return (
      <div className="mx-auto max-w-3xl px-4 py-8">
        <div className="card p-6 space-y-4">
          <div className="skeleton h-8 w-1/2" />
          <div className="skeleton h-4 w-full" />
          <div className="skeleton h-40 w-full" />
        </div>
      </div>
    );
  }

  if (!post) return null;

  return (
    <div className="mx-auto max-w-3xl px-4 py-8">
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold">{t.postEditor.editTitle}</h1>
        <button
          onClick={togglePublish}
          className={`btn ${post.is_published ? "btn-outline" : "btn-primary"}`}
        >
          {post.is_published
            ? <><EyeOff size={15} /> {t.postEditor.unpublish}</>
            : <><Send size={15} /> {t.dashboard.publish}</>}
        </button>
      </div>

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
        <div className="card p-6 space-y-5">
          {/* Status */}
          <div className="flex items-center gap-2 text-sm">
            {post.is_published ? (
              <span className="flex items-center gap-1.5 text-green-600">
                <Eye size={14} /> {t.dashboard.published}
              </span>
            ) : (
              <span className="flex items-center gap-1.5 text-gray-400">
                <EyeOff size={14} /> {t.post.draft}
              </span>
            )}
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium">{t.postEditor.titleLabel}</label>
            <input className="input" {...register("title")} />
            {errors.title && <p className="mt-1 text-xs text-red-500">{t.postEditor.titleRequired}</p>}
          </div>

          <div>
            <label className="mb-2 block text-sm font-medium">{t.postEditor.contentLabel}</label>
            <Controller
              name="content"
              control={control}
              render={({ field }) => (
                <RichTextEditor
                  value={field.value ?? ""}
                  onChange={field.onChange}
                  placeholder={t.postEditor.contentPlaceholder}
                />
              )}
            />
          </div>

          <label className="flex cursor-pointer items-center gap-2 text-sm">
            <input type="checkbox" className="rounded border-gray-300 text-brand-600" {...register("is_free")} />
            {t.postEditor.freePost}
          </label>

          {serverError && (
            <div className="rounded-lg bg-red-50 px-4 py-3 text-sm text-red-600">{serverError}</div>
          )}

          <div className="flex gap-3">
            <button type="submit" disabled={isSubmitting} className="btn-primary">
              {isSubmitting ? t.postEditor.saving : t.common.save}
            </button>
            <button type="button" onClick={() => router.back()} className="btn-outline">
              {t.common.cancel}
            </button>
          </div>
        </div>

        <div className="card p-6">
          <h2 className="mb-4 font-semibold">{t.postEditor.attachments}</h2>
          <FileUploader
            postId={id}
            attachments={attachments}
            onChange={setAttachments}
          />
        </div>
      </form>
    </div>
  );
}
