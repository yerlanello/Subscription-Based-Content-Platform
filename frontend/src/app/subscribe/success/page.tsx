"use client";

import { CheckCircle, Loader2, XCircle } from "lucide-react";
import Link from "next/link";
import { useEffect, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { useRouter, useSearchParams } from "next/navigation";
import { subscriptionsApi } from "@/lib/api";

export default function SubscribeSuccessPage() {
  const queryClient = useQueryClient();
  const router = useRouter();
  const searchParams = useSearchParams();
  const creator = searchParams.get("creator");
  const sessionId = searchParams.get("session_id");

  const [status, setStatus] = useState<"loading" | "success" | "error">("loading");
  const [errorMsg, setErrorMsg] = useState("");

  useEffect(() => {
    if (!sessionId) {
      setStatus("error");
      setErrorMsg("Нет идентификатора сессии");
      return;
    }

    subscriptionsApi
      .verifySession(sessionId)
      .then(() => {
        setStatus("success");
        queryClient.invalidateQueries();
        // Редирект на страницу автора через 2 сек
        setTimeout(() => {
          router.push(creator ? `/${creator}` : "/feed");
        }, 2000);
      })
      .catch((err) => {
        const msg =
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          (err as any)?.response?.data?.error ?? "Ошибка при подтверждении подписки";
        setErrorMsg(msg);
        setStatus("error");
      });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sessionId]);

  if (status === "loading") {
    return (
      <div className="flex min-h-[60vh] items-center justify-center px-4">
        <div className="card w-full max-w-md p-8 text-center">
          <Loader2 size={48} className="mx-auto mb-4 animate-spin text-brand-500" />
          <p className="font-medium">Подтверждаем оплату...</p>
        </div>
      </div>
    );
  }

  if (status === "error") {
    return (
      <div className="flex min-h-[60vh] items-center justify-center px-4">
        <div className="card w-full max-w-md p-8 text-center">
          <XCircle size={48} className="mx-auto mb-4 text-red-500" />
          <h1 className="mb-2 text-xl font-bold">Что-то пошло не так</h1>
          <p className="mb-6 text-sm text-gray-500">{errorMsg}</p>
          <Link href={creator ? `/${creator}` : "/"} className="btn-primary w-full justify-center">
            Вернуться назад
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-[60vh] items-center justify-center px-4">
      <div className="card w-full max-w-md p-8 text-center">
        <CheckCircle size={56} className="mx-auto mb-4 text-green-500" />
        <h1 className="mb-2 text-2xl font-bold">Подписка оформлена!</h1>
        <p className="mb-4 text-gray-500">
          Оплата прошла успешно. Теперь у вас есть доступ ко всему контенту автора.
        </p>
        <div className="flex items-center justify-center gap-2 text-sm text-gray-400">
          <Loader2 size={14} className="animate-spin" />
          Перенаправление...
        </div>
      </div>
    </div>
  );
}
