"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { authApi } from "@/lib/api";
import { useAuth } from "@/hooks/useAuth";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useState } from "react";

const schema = z.object({
  email: z.string().email("Неверный email"),
  password: z.string().min(1, "Введите пароль"),
});

type Form = z.infer<typeof schema>;

export default function LoginPage() {
  const { login } = useAuth();
  const router = useRouter();
  const [serverError, setServerError] = useState("");

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
      router.push("/feed");
    } catch (err: unknown) {
      const e = err as { response?: { data?: { error?: string } } };
      setServerError(e.response?.data?.error ?? "Ошибка входа");
    }
  };

  return (
    <div className="flex min-h-[80vh] items-center justify-center px-4">
      <div className="card w-full max-w-md p-8">
        <h1 className="mb-6 text-2xl font-bold">Вход</h1>

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <div>
            <label className="mb-1 block text-sm font-medium">Email</label>
            <input className="input" type="email" placeholder="you@example.com" {...register("email")} />
            {errors.email && <p className="mt-1 text-xs text-red-500">{errors.email.message}</p>}
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium">Пароль</label>
            <input className="input" type="password" placeholder="••••••••" {...register("password")} />
            {errors.password && <p className="mt-1 text-xs text-red-500">{errors.password.message}</p>}
          </div>

          {serverError && (
            <div className="rounded-lg bg-red-50 px-4 py-3 text-sm text-red-600">{serverError}</div>
          )}

          <button type="submit" disabled={isSubmitting} className="btn-primary w-full">
            {isSubmitting ? "Входим..." : "Войти"}
          </button>
        </form>

        <p className="mt-4 text-center text-sm text-gray-500">
          Нет аккаунта?{" "}
          <Link href="/register" className="text-brand-600 hover:underline">
            Зарегистрироваться
          </Link>
        </p>
      </div>
    </div>
  );
}
