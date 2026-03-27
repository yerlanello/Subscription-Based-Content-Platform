"use client";

import { useState } from "react";
import { donationsApi } from "@/lib/api";
import { X, Gift } from "lucide-react";

const PRESET_AMOUNTS = [500, 1000, 2000, 5000];

interface Props {
  username: string;
  displayName: string;
  onClose: () => void;
}

export function DonateModal({ username, displayName, onClose }: Props) {
  const [amount, setAmount] = useState<number>(1000);
  const [customAmount, setCustomAmount] = useState("");
  const [message, setMessage] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const finalAmount = customAmount ? parseInt(customAmount, 10) : amount;

  const handleDonate = async () => {
    if (!finalAmount || finalAmount < 100) {
      setError("Минимальная сумма доната — 100 ₸");
      return;
    }
    setError(null);
    setIsLoading(true);
    try {
      const res = await donationsApi.createCheckout(username, {
        amount_cents: finalAmount,
        message: message.trim() || undefined,
      });
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const url = (res.data as any)?.data?.url ?? (res.data as any)?.url;
      if (!url) throw new Error("Не удалось получить ссылку на оплату");
      window.location.href = url;
    } catch (err: unknown) {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      setError((err as any)?.response?.data?.error ?? "Ошибка при создании платежа");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div className="card w-full max-w-md p-6 shadow-xl">
        <div className="mb-4 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Gift size={20} className="text-brand-600" />
            <h2 className="text-lg font-semibold">Задонатить {displayName}</h2>
          </div>
          <button onClick={onClose} className="btn-ghost p-1">
            <X size={18} />
          </button>
        </div>

        {/* Preset amounts */}
        <div className="mb-4">
          <p className="mb-2 text-sm text-gray-500 dark:text-gray-400">Выберите сумму</p>
          <div className="grid grid-cols-4 gap-2">
            {PRESET_AMOUNTS.map((a) => (
              <button
                key={a}
                onClick={() => {
                  setAmount(a);
                  setCustomAmount("");
                }}
                className={`rounded-lg border py-2 text-sm font-medium transition-colors ${
                  !customAmount && amount === a
                    ? "border-brand-500 bg-brand-50 dark:bg-brand-950 text-brand-600"
                    : "border-gray-200 dark:border-gray-700 hover:border-brand-300"
                }`}
              >
                {a.toLocaleString()} ₸
              </button>
            ))}
          </div>
        </div>

        {/* Custom amount */}
        <div className="mb-4">
          <label className="mb-1 block text-sm text-gray-500 dark:text-gray-400">
            Или своя сумма (₸)
          </label>
          <input
            type="number"
            min={100}
            className="input"
            placeholder="Например: 3000"
            value={customAmount}
            onChange={(e) => setCustomAmount(e.target.value)}
          />
        </div>

        {/* Message */}
        <div className="mb-4">
          <label className="mb-1 block text-sm text-gray-500 dark:text-gray-400">
            Сообщение автору (необязательно)
          </label>
          <textarea
            className="input resize-none"
            rows={3}
            placeholder="Напишите что-нибудь..."
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            maxLength={300}
          />
        </div>

        {error && <p className="mb-3 text-sm text-red-500">{error}</p>}

        <div className="flex gap-3">
          <button onClick={onClose} className="btn-outline flex-1">
            Отмена
          </button>
          <button
            onClick={handleDonate}
            disabled={isLoading || !finalAmount}
            className="btn-primary flex-1"
          >
            <Gift size={16} />
            {isLoading
              ? "Загрузка..."
              : `Задонатить ${(finalAmount || 0).toLocaleString()} ₸`}
          </button>
        </div>
      </div>
    </div>
  );
}
