"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { authApi } from "@/lib/api";
import { useAuth } from "@/hooks/useAuth";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useState } from "react";
import { useT } from "@/hooks/useT";

export default function LoginPage() {
  const { login } = useAuth();
  const router = useRouter();
  const t = useT();
  const [serverError, setServerError] = useState("");

  const schema = z.object({
    email: z.string().email("Неверный email"),
    password: z.string().min(1, "Введите пароль"),
  });
  type Form = z.infer<typeof schema>;

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<Form>({ resolver: zodResolver(schema) });

  const onSubmit = async (values: Form) => {
    setServerError("");
    try {
      const res = await authApi.login(values);
      const { user, access_token, refresh_token } = res.data.data;
      login(user, access_token, refresh_token);
      if (!user.email_verified) {
        router.push("/check-email");
      } else {
        router.push("/feed");
      }
    } catch (err: unknown) {
      const e = err as { response?: { data?: { error?: string } } };
      setServerError(e.response?.data?.error ?? t.auth.loginError);
    }
  };

  return (
    <div className="flex min-h-[80vh] items-center justify-center px-4">
      <div className="card w-full max-w-md p-8">
        <h1 className="mb-6 text-2xl font-bold">{t.auth.loginTitle}</h1>

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <div>
            <label className="mb-1 block text-sm font-medium">{t.auth.email}</label>
            <input className="input" type="email" placeholder="you@example.com" {...register("email")} />
            {errors.email && <p className="mt-1 text-xs text-red-500">{errors.email.message}</p>}
          </div>

          <div>
            <div className="mb-1 flex items-center justify-between">
              <label className="text-sm font-medium">{t.auth.password}</label>
              <Link href="/forgot-password" className="text-xs text-brand-600 hover:underline">
                Забыли пароль?
              </Link>
            </div>
            <input className="input" type="password" placeholder="••••••••" {...register("password")} />
            {errors.password && <p className="mt-1 text-xs text-red-500">{errors.password.message}</p>}
          </div>

          {serverError && (
            <div className="rounded-lg bg-red-50 px-4 py-3 text-sm text-red-600">{serverError}</div>
          )}

          <button type="submit" disabled={isSubmitting} className="btn-primary w-full">
            {isSubmitting ? t.auth.loggingIn : t.auth.login}
          </button>
        </form>

        <p className="mt-4 text-center text-sm text-gray-500">
          {t.auth.noAccount}{" "}
          <Link href="/register" className="text-brand-600 hover:underline">
            {t.auth.loginLink}
          </Link>
        </p>
      </div>
    </div>
  );
}
