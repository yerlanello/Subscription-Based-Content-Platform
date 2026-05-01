"use client";

import { useState } from "react";
import { useAuth } from "@/hooks/useAuth";
import { authApi } from "@/lib/api";
import Link from "next/link";
import { Mail } from "lucide-react";

export default function CheckEmailPage() {
  const { user } = useAuth();
  const [sent, setSent] = useState(false);
  const [loading, setLoading] = useState(false);

  const handleResend = async () => {
    setLoading(true);
    try {
      await authApi.resendVerification();
      setSent(true);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-[80vh] items-center justify-center px-4">
      <div className="card w-full max-w-md p-8 text-center">
        <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-brand-100 dark:bg-brand-900/30">
          <Mail size={32} className="text-brand-600" />
        </div>

        <h1 className="mb-2 text-2xl font-bold">Подтвердите email</h1>
        <p className="mb-1 text-gray-500">
          Мы отправили письмо с ссылкой для подтверждения на
        </p>
        <p className="mb-6 font-semibold text-gray-800 dark:text-gray-200">
          {user?.email ?? "ваш email"}
        </p>

        <p className="mb-6 text-sm text-gray-400">
          Откройте письмо и нажмите кнопку «Подтвердить email». Письмо может прийти в папку «Спам».
        </p>

        {sent ? (
          <div className="rounded-lg bg-green-50 dark:bg-green-900/20 px-4 py-3 text-sm text-green-700 dark:text-green-300">
            Письмо отправлено повторно!
          </div>
        ) : (
          <button
            onClick={handleResend}
            disabled={loading}
            className="btn-outline w-full"
          >
            {loading ? "Отправляем…" : "Отправить повторно"}
          </button>
        )}

        <p className="mt-6 text-sm text-gray-400">
          <Link href="/" className="text-brand-600 hover:underline">
            Перейти на сайт
          </Link>
          {" — "}некоторые функции будут ограничены до подтверждения.
        </p>
      </div>
    </div>
  );
}
