"use client";

import { useState } from "react";
import { creatorsApi } from "@/lib/api";
import { useQueryClient } from "@tanstack/react-query";
import { X } from "lucide-react";

export function BecomeCreatorModal({ onClose }: { onClose: () => void }) {
  const [displayName, setDisplayName] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const queryClient = useQueryClient();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!displayName.trim()) return;
    setLoading(true);
    try {
      await creatorsApi.becomeCreator({ display_name: displayName });
      queryClient.invalidateQueries({ queryKey: ["my-creator"] });
      window.location.reload();
    } catch {
      setError("Не удалось создать профиль");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 px-4">
      <div className="card w-full max-w-md p-6">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-semibold">Создать профиль автора</h2>
          <button onClick={onClose} className="btn-ghost p-1">
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="mb-1 block text-sm font-medium">Отображаемое имя</label>
            <input
              className="input"
              placeholder="Ваше творческое имя"
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
              autoFocus
            />
          </div>

          {error && (
            <div className="rounded-lg bg-red-50 px-4 py-3 text-sm text-red-600">{error}</div>
          )}

          <button type="submit" disabled={loading || !displayName.trim()} className="btn-primary w-full">
            {loading ? "Создаём..." : "Создать"}
          </button>
        </form>
      </div>
    </div>
  );
}
