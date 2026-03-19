"use client";

import { useRef, useState } from "react";
import { postsApi } from "@/lib/api";
import { PostAttachment } from "@/lib/types";
import { Upload, X, Image, Film, Music, FileIcon } from "lucide-react";

interface Props {
  postId: string;
  attachments: PostAttachment[];
  onChange: (attachments: PostAttachment[]) => void;
}

function AttachmentIcon({ mimeType }: { mimeType: string | null }) {
  if (mimeType?.startsWith("image/")) return <Image size={14} />;
  if (mimeType?.startsWith("video/")) return <Film size={14} />;
  if (mimeType?.startsWith("audio/")) return <Music size={14} />;
  return <FileIcon size={14} />;
}

function AttachmentPreview({ attachment, onDelete }: { attachment: PostAttachment; onDelete: () => void }) {
  const mime = attachment.mime_type ?? "";

  return (
    <div className="relative group rounded-xl overflow-hidden border border-gray-200 bg-gray-50">
      {mime.startsWith("image/") && (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={attachment.url} alt="" className="h-40 w-full object-cover" />
      )}
      {mime.startsWith("video/") && (
        <video src={attachment.url} controls className="h-40 w-full object-cover" />
      )}
      {mime.startsWith("audio/") && (
        <div className="flex flex-col items-center gap-2 p-4">
          <Music size={28} className="text-brand-400" />
          <audio src={attachment.url} controls className="w-full" />
        </div>
      )}
      {!mime.startsWith("image/") && !mime.startsWith("video/") && !mime.startsWith("audio/") && (
        <div className="flex items-center gap-2 p-3">
          <FileIcon size={20} className="text-gray-400" />
          <span className="text-sm text-gray-600 truncate">{attachment.url.split("/").pop()}</span>
        </div>
      )}

      <button
        onClick={onDelete}
        className="absolute right-2 top-2 flex h-6 w-6 items-center justify-center rounded-full bg-black/60 text-white opacity-0 transition-opacity group-hover:opacity-100 hover:bg-black/80"
      >
        <X size={12} />
      </button>

      <div className="absolute bottom-2 left-2 flex items-center gap-1 rounded-full bg-black/60 px-2 py-0.5 text-[10px] text-white">
        <AttachmentIcon mimeType={mime} />
        {mime.split("/")[0]}
      </div>
    </div>
  );
}

export function FileUploader({ postId, attachments, onChange }: Props) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState("");

  const handleFiles = async (files: FileList | null) => {
    if (!files || files.length === 0) return;
    setUploading(true);
    setError("");

    const newAttachments: PostAttachment[] = [];
    for (const file of Array.from(files)) {
      try {
        const formData = new FormData();
        formData.append("file", file);
        const res = await postsApi.uploadAttachment(postId, formData);
        newAttachments.push(res.data.data as PostAttachment);
      } catch {
        setError(`Не удалось загрузить ${file.name}`);
      }
    }

    onChange([...attachments, ...newAttachments]);
    setUploading(false);
    if (inputRef.current) inputRef.current.value = "";
  };

  const handleDelete = async (attachment: PostAttachment) => {
    try {
      await postsApi.deleteAttachment(postId, attachment.id);
      onChange(attachments.filter((a) => a.id !== attachment.id));
    } catch {
      setError("Не удалось удалить файл");
    }
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    handleFiles(e.dataTransfer.files);
  };

  return (
    <div className="space-y-3">
      {/* Превью загруженных файлов */}
      {attachments.length > 0 && (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
          {attachments.map((a) => (
            <AttachmentPreview key={a.id} attachment={a} onDelete={() => handleDelete(a)} />
          ))}
        </div>
      )}

      {/* Зона загрузки */}
      <div
        onDrop={handleDrop}
        onDragOver={(e) => e.preventDefault()}
        onClick={() => inputRef.current?.click()}
        className="flex cursor-pointer flex-col items-center gap-2 rounded-xl border-2 border-dashed border-gray-300 p-6 text-center transition-colors hover:border-brand-400 hover:bg-brand-50"
      >
        <Upload size={20} className="text-gray-400" />
        <div>
          <p className="text-sm font-medium text-gray-600">
            {uploading ? "Загружаем..." : "Нажмите или перетащите файлы"}
          </p>
          <p className="mt-0.5 text-xs text-gray-400">
            Фото, видео, аудио · до 50 MB
          </p>
        </div>
        <input
          ref={inputRef}
          type="file"
          multiple
          accept="image/*,video/mp4,video/webm,video/quicktime,audio/mpeg,audio/wav,audio/ogg,audio/mp4"
          className="hidden"
          onChange={(e) => handleFiles(e.target.files)}
          disabled={uploading}
        />
      </div>

      {error && <p className="text-xs text-red-500">{error}</p>}
    </div>
  );
}
