"use client";

import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import Link from "next/link";
import { authApi, usersApi } from "@/lib/api";
import { useAuthStore } from "@/store/authStore";

export default function VerifyEmailPage() {
  const searchParams = useSearchParams();
  const token = searchParams.get("token") ?? "";
  const setUser = useAuthStore((s) => s.setUser);

  const [status, setStatus] = useState<"loading" | "success" | "error">("loading");

  useEffect(() => {
    if (!token) {
      setStatus("error");
      return;
    }
    authApi
      .verifyEmail(token)
      .then(() => {
        // Refresh user data so the banner disappears
        return usersApi.me().then((res) => setUser(res.data.data));
      })
      .then(() => setStatus("success"))
      .catch(() => setStatus("error"));
  }, [token, setUser]);

  return (
    <div className="flex min-h-[80vh] items-center justify-center px-4">
      <div className="card w-full max-w-md p-8 text-center">
        {status === "loading" && (
          <>
            <div className="mx-auto mb-4 h-10 w-10 animate-spin rounded-full border-4 border-brand-600 border-t-transparent" />
            <p className="text-gray-500">Проверяем ссылку…</p>
          </>
        )}

        {status === "success" && (
          <>
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-green-100 text-3xl">
              ✓
            </div>
            <h1 className="mb-2 text-2xl font-bold text-green-700">Email подтверждён!</h1>
            <p className="mb-6 text-gray-500">Ваш адрес электронной почты успешно подтверждён.</p>
            <Link href="/" className="btn-primary">
              Перейти на главную
            </Link>
          </>
        )}

        {status === "error" && (
          <>
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-red-100 text-3xl">
              ✕
            </div>
            <h1 className="mb-2 text-2xl font-bold text-red-600">Ссылка недействительна</h1>
            <p className="mb-6 text-gray-500">
              Ссылка для подтверждения устарела или уже использована.
            </p>
            <Link href="/" className="btn-outline">
              На главную
            </Link>
          </>
        )}
      </div>
    </div>
  );
}
