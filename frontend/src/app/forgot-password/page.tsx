"use client";

import { useState } from "react";
import { authApi } from "@/lib/api";
import Link from "next/link";

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState("");
  const [submitted, setSubmitted] = useState(false);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email) return;
    setLoading(true);
    try {
      await authApi.forgotPassword(email);
    } finally {
      setLoading(false);
      setSubmitted(true);
    }
  };

  return (
    <div className="flex min-h-[80vh] items-center justify-center px-4">
      <div className="card w-full max-w-md p-8">
        <h1 className="mb-2 text-2xl font-bold">Забыли пароль?</h1>
        <p className="mb-6 text-sm text-gray-500">
          Введите email вашего аккаунта и мы отправим инструкции по сбросу пароля.
        </p>

        {submitted ? (
          <div className="rounded-lg bg-green-50 dark:bg-green-900/20 px-4 py-4 text-sm text-green-700 dark:text-green-300">
            Если такой email зарегистрирован, мы отправили инструкции по сбросу пароля.
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="mb-1 block text-sm font-medium">Email</label>
              <input
                className="input"
                type="email"
                placeholder="you@example.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
              />
            </div>

            <button type="submit" disabled={loading} className="btn-primary w-full">
              {loading ? "Отправляем…" : "Отправить инструкции"}
            </button>
          </form>
        )}

        <p className="mt-4 text-center text-sm text-gray-500">
          Вспомнили пароль?{" "}
          <Link href="/login" className="text-brand-600 hover:underline">
            Войти
          </Link>
        </p>
      </div>
    </div>
  );
}
