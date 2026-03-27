"use client";

import Link from "next/link";
import { Rss, Lock, Gift, Heart, ArrowRight, Star } from "lucide-react";

const FEATURES = [
  {
    icon: <Lock size={24} className="text-brand-600" />,
    title: "Эксклюзивный контент",
    desc: "Получайте доступ к закрытым постам, которые авторы создают только для подписчиков.",
  },
  {
    icon: <Rss size={24} className="text-brand-600" />,
    title: "Персональная лента",
    desc: "Все обновления от авторов, на которых вы подписаны, в одном месте.",
  },
  {
    icon: <Gift size={24} className="text-brand-600" />,
    title: "Донаты",
    desc: "Поддержите любимого автора напрямую разовым донатом в любой сумме.",
  },
  {
    icon: <Heart size={24} className="text-brand-600" />,
    title: "Подписки",
    desc: "Следите за авторами и получайте уведомления о новых публикациях.",
  },
];

const STATS = [
  { value: "100+", label: "Авторов" },
  { value: "500+", label: "Подписчиков" },
  { value: "1000+", label: "Публикаций" },
];

export function LandingPage() {
  return (
    <div className="flex flex-col">
      {/* Hero */}
      <section className="relative overflow-hidden bg-gradient-to-br from-brand-600 via-purple-600 to-indigo-700 py-24 text-white">
        {/* Decorative blobs */}
        <div className="pointer-events-none absolute -top-32 -left-32 h-96 w-96 rounded-full bg-white/10 blur-3xl" />
        <div className="pointer-events-none absolute -bottom-32 -right-32 h-96 w-96 rounded-full bg-white/10 blur-3xl" />

        <div className="relative mx-auto max-w-4xl px-4 text-center">
          <div className="mb-4 inline-flex items-center gap-2 rounded-full bg-white/20 px-4 py-1.5 text-sm font-medium backdrop-blur-sm">
            <Star size={14} className="fill-yellow-300 text-yellow-300" />
            Платформа для авторов и их аудитории
          </div>

          <h1 className="mb-6 text-5xl font-extrabold leading-tight sm:text-6xl">
            Поддержи любимых
            <br />
            <span className="text-yellow-300">авторов</span>
          </h1>

          <p className="mb-10 mx-auto max-w-xl text-lg text-white/80">
            Подписывайся на авторов, получай эксклюзивный контент и поддерживай
            тех, кто создаёт то, что ты любишь
          </p>

          <div className="flex flex-col items-center gap-4 sm:flex-row sm:justify-center">
            <Link
              href="/register"
              className="flex items-center gap-2 rounded-xl bg-white px-8 py-3 text-base font-semibold text-brand-700 shadow-lg transition-all hover:scale-105 hover:shadow-xl"
            >
              Начать бесплатно
              <ArrowRight size={18} />
            </Link>
            <Link
              href="/login"
              className="flex items-center gap-2 rounded-xl border border-white/40 bg-white/10 px-8 py-3 text-base font-semibold text-white backdrop-blur-sm transition-all hover:bg-white/20"
            >
              Войти
            </Link>
          </div>

          {/* Stats */}
          <div className="mt-16 flex justify-center gap-12">
            {STATS.map((s) => (
              <div key={s.label} className="text-center">
                <p className="text-3xl font-extrabold">{s.value}</p>
                <p className="text-sm text-white/70">{s.label}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="bg-gray-50 dark:bg-gray-950 py-20">
        <div className="mx-auto max-w-6xl px-4">
          <h2 className="mb-4 text-center text-3xl font-bold text-gray-900 dark:text-gray-100">
            Всё что нужно авторам и их аудитории
          </h2>
          <p className="mb-12 text-center text-gray-500 dark:text-gray-400">
            Простой способ монетизировать контент и найти свою аудиторию
          </p>

          <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
            {FEATURES.map((f) => (
              <div key={f.title} className="card p-6 hover:shadow-md transition-shadow">
                <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-xl bg-brand-50 dark:bg-brand-950">
                  {f.icon}
                </div>
                <h3 className="mb-2 font-semibold">{f.title}</h3>
                <p className="text-sm text-gray-500 dark:text-gray-400">{f.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA for creators */}
      <section className="bg-white dark:bg-gray-900 py-20">
        <div className="mx-auto max-w-3xl px-4 text-center">
          <h2 className="mb-4 text-3xl font-bold text-gray-900 dark:text-gray-100">Ты автор?</h2>
          <p className="mb-8 text-gray-500 dark:text-gray-400">
            Создавай контент, устанавливай подписку и зарабатывай на своём творчестве.
            Платные посты доступны только подписчикам.
          </p>
          <Link
            href="/register"
            className="btn-primary inline-flex px-8 py-3 text-base"
          >
            Стать автором
            <ArrowRight size={18} />
          </Link>
        </div>
      </section>
    </div>
  );
}
