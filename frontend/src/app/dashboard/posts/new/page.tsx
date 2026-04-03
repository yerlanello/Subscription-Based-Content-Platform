"use client";

import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { postsApi } from "@/lib/api";
import { useRouter } from "next/navigation";
import { useState, useRef } from "react";
import { useAuth } from "@/hooks/useAuth";
import { useQueryClient } from "@tanstack/react-query";
import { useT } from "@/hooks/useT";
import { Upload, X, Image, Film, Music, FileIcon, AlertCircle, Info } from "lucide-react";
import { RichTextEditor } from "@/components/post/RichTextEditor";

// Allowed extensions — mirrors backend allowedMimeTypes
const ALLOWED_EXTS: Record<string, string> = {
  ".jpg": "image", ".jpeg": "image", ".png": "image", ".webp": "image", ".gif": "image",
  ".mp4": "video", ".webm": "video", ".mov": "video",
  ".mp3": "audio", ".wav": "audio", ".ogg": "audio", ".m4a": "audio",
};

function getExt(name: string) {
  return name.slice(name.lastIndexOf(".")).toLowerCase();
}

function isAllowed(file: File) {
  return getExt(file.name) in ALLOWED_EXTS;
}

const schema = z.object({
  title: z.string().min(1).max(300),
  content: z.string().optional(),
  is_free: z.boolean(),
  publish_now: z.boolean(),
});

type Form = z.infer<typeof schema>;

function FileTypeIcon({ file }: { file: File }) {
  if (file.type.startsWith("image/")) return <Image size={14} />;
  if (file.type.startsWith("video/")) return <Film size={14} />;
  if (file.type.startsWith("audio/")) return <Music size={14} />;
  return <FileIcon size={14} />;
}

export default function NewPostPage() {
  const router = useRouter();
  const { user } = useAuth();
  const queryClient = useQueryClient();
  const t = useT();
  const [serverError, setServerError] = useState("");
  const [fileErrors, setFileErrors] = useState<string[]>([]);
  const [rejectedFiles, setRejectedFiles] = useState<string[]>([]);
  const [pendingFiles, setPendingFiles] = useState<File[]>([]);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const { register, handleSubmit, control, formState: { errors, isSubmitting } } = useForm<Form>({
    resolver: zodResolver(schema),
    defaultValues: { is_free: false, publish_now: true },
  });

  const addFiles = (files: FileList | null) => {
    if (!files) return;
    const all = Array.from(files);
    const valid = all.filter(isAllowed);
    const rejected = all.filter((f) => !isAllowed(f)).map((f) => f.name);
    setPendingFiles((prev) => [...prev, ...valid]);
    setRejectedFiles(rejected);
    if (fileInputRef.current) fileInputRef.current.value = "";
  };

  const onSubmit = async (values: Form) => {
    setServerError("");
    setFileErrors([]);
    try {
      const res = await postsApi.create({
        title: values.title,
        content: values.content || undefined,
        type: "text",
        is_free: values.is_free,
      });
      const post = res.data.data;

      const uploadErrors: string[] = [];
      for (const file of pendingFiles) {
        try {
          const fd = new FormData();
          fd.append("file", file);
          await postsApi.uploadAttachment(post.id, fd);
        } catch {
          uploadErrors.push(`${t.postEditor.uploadFileError}: ${file.name}`);
        }
      }

      if (uploadErrors.length > 0) {
        setFileErrors(uploadErrors);
        // Post was created — still navigate but show warnings
      }

      if (values.publish_now) {
        await postsApi.publish(post.id);
      }
      await queryClient.invalidateQueries({ queryKey: ["my-posts"] });
      await queryClient.invalidateQueries({ queryKey: ["creator-posts"] });
      router.push("/dashboard");
    } catch {
      setServerError(t.postEditor.createError);
    }
  };

  if (!user) return null;

  return (
    <div className="mx-auto max-w-3xl px-4 py-8">
      <h1 className="mb-6 text-2xl font-bold">{t.postEditor.newTitle}</h1>

      <form onSubmit={handleSubmit(onSubmit)} className="card p-6 space-y-5">
        <div>
          <label className="mb-1 block text-sm font-medium">{t.postEditor.titleLabel}</label>
          <input className="input" placeholder={t.postEditor.titlePlaceholder} {...register("title")} />
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

        {/* File staging */}
        <div>
          <label className="mb-2 block text-sm font-medium">{t.postEditor.attachments}</label>

          {/* Accepted files */}
          {pendingFiles.length > 0 && (
            <div className="mb-2 space-y-1">
              {pendingFiles.map((f, i) => (
                <div key={i} className="flex items-center justify-between rounded-lg bg-gray-50 dark:bg-gray-800 px-3 py-2 text-sm">
                  <span className="flex items-center gap-2 truncate">
                    <FileTypeIcon file={f} />
                    <span className="truncate">{f.name}</span>
                  </span>
                  <button
                    type="button"
                    onClick={() => setPendingFiles((prev) => prev.filter((_, j) => j !== i))}
                    className="ml-2 shrink-0 text-gray-400 hover:text-red-500"
                  >
                    <X size={14} />
                  </button>
                </div>
              ))}
            </div>
          )}

          {/* Rejected files warning */}
          {rejectedFiles.length > 0 && (
            <div className="mb-2 rounded-lg border border-red-200 dark:border-red-800 bg-red-50 dark:bg-red-950/30 px-4 py-3">
              <div className="flex items-center gap-2 text-sm font-medium text-red-600 dark:text-red-400 mb-1">
                <AlertCircle size={15} />
                {t.postEditor.rejectedFiles}:
              </div>
              <ul className="ml-5 list-disc space-y-0.5 text-xs text-red-500 dark:text-red-400">
                {rejectedFiles.map((name) => (
                  <li key={name}>{name}</li>
                ))}
              </ul>
              <p className="mt-2 text-xs text-red-400 dark:text-red-500">{t.postEditor.supportedFormats}</p>
            </div>
          )}

          {/* Upload errors (per-file) */}
          {fileErrors.length > 0 && (
            <div className="mb-2 rounded-lg border border-amber-200 dark:border-amber-800 bg-amber-50 dark:bg-amber-950/30 px-4 py-3">
              <ul className="space-y-0.5 text-xs text-amber-700 dark:text-amber-400">
                {fileErrors.map((e) => <li key={e}>{e}</li>)}
              </ul>
            </div>
          )}

          <div
            onClick={() => { setRejectedFiles([]); fileInputRef.current?.click(); }}
            onDrop={(e) => { e.preventDefault(); addFiles(e.dataTransfer.files); }}
            onDragOver={(e) => e.preventDefault()}
            className="flex cursor-pointer flex-col items-center gap-2 rounded-xl border-2 border-dashed border-gray-300 dark:border-gray-600 p-5 text-center transition-colors hover:border-brand-400 hover:bg-brand-50 dark:hover:bg-brand-950"
          >
            <Upload size={18} className="text-gray-400" />
            <p className="text-sm text-gray-500">{t.postEditor.dropFiles}</p>
          </div>
          <p className="mt-1.5 flex items-center gap-1 text-xs text-gray-400">
            <Info size={11} />
            {t.postEditor.supportedFormats}
          </p>
          <input
            ref={fileInputRef}
            type="file"
            multiple
            accept=".jpg,.jpeg,.png,.webp,.gif,.mp4,.webm,.mov,.mp3,.wav,.ogg,.m4a"
            className="hidden"
            onChange={(e) => addFiles(e.target.files)}
          />
        </div>

        <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
          <label className="flex cursor-pointer items-center gap-2 text-sm">
            <input type="checkbox" className="rounded border-gray-300 text-brand-600" {...register("is_free")} />
            {t.postEditor.freePost}
          </label>
          <label className="flex cursor-pointer items-center gap-2 text-sm">
            <input type="checkbox" className="rounded border-gray-300 text-brand-600" {...register("publish_now")} />
            {t.postEditor.publishNow}
          </label>
        </div>

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
      </form>
    </div>
  );
}
