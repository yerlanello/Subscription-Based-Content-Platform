"use client";

import Link from "next/link";
import { useAuth } from "@/hooks/useAuth";
import { authApi } from "@/lib/api";
import { getTokens } from "@/lib/auth";
import { useRouter, usePathname } from "next/navigation";
import { User, LayoutDashboard, LogOut, Rss, Home, Moon, Sun, Heart, Globe, CreditCard, Radio } from "lucide-react";
import { useState, useEffect, useRef } from "react";
import { NotificationBell } from "./NotificationBell";
import { NotificationToasts } from "./NotificationToasts";
import { useSSENotifications } from "@/hooks/useNotifications";
import { useLocaleStore } from "@/store/localeStore";
import { type Locale } from "@/locales";
import { useT } from "@/hooks/useT";

const LOCALES: { value: Locale; label: string }[] = [
  { value: "ru", label: "RU" },
  { value: "en", label: "EN" },
  { value: "kk", label: "KZ" },
];

export function Navbar() {
  const { user, logout } = useAuth();
  const router = useRouter();
  const pathname = usePathname();
  const [menuOpen, setMenuOpen] = useState(false);
  const [langOpen, setLangOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const langRef = useRef<HTMLDivElement>(null);
  const { toasts, dismissToast } = useSSENotifications(!!user);
  const t = useT();
  const { locale, setLocale } = useLocaleStore();

  const [isDark, setIsDark] = useState(false);

  useEffect(() => {
    // Восстанавливаем locale из localStorage
    const savedLocale = localStorage.getItem("locale") as Locale | null;
    if (savedLocale && (savedLocale === "ru" || savedLocale === "en" || savedLocale === "kk")) {
      setLocale(savedLocale);
    }
    setIsDark(document.documentElement.classList.contains("dark"));
  }, []);

  const toggleTheme = () => {
    const currentlyDark = document.documentElement.classList.contains("dark");
    const newDark = !currentlyDark;
    document.documentElement.classList.toggle("dark", newDark);
    localStorage.setItem("theme", newDark ? "dark" : "light");
    setIsDark(newDark);
  };

  const theme = isDark ? "dark" : "light";

  // Закрываем при смене страницы
  useEffect(() => {
    setMenuOpen(false);
    setLangOpen(false);
  }, [pathname]);

  // Закрываем при клике вне меню
  useEffect(() => {
    if (!menuOpen && !langOpen) return;
    const handleClick = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setMenuOpen(false);
      }
      if (langRef.current && !langRef.current.contains(e.target as Node)) {
        setLangOpen(false);
      }
    };
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [menuOpen, langOpen]);

  const handleLogout = async () => {
    const { refreshToken } = getTokens();
    if (refreshToken) {
      await authApi.logout(refreshToken).catch(() => {});
    }
    logout();
    router.push("/");
  };

  const [resendingSent, setResendingSent] = useState(false);

  const handleResendVerification = async () => {
    try {
      await authApi.resendVerification();
      setResendingSent(true);
    } catch {
      // silently ignore
    }
  };

  return (
    <>
    <NotificationToasts toasts={toasts} onDismiss={dismissToast} />
    {user && !user.email_verified && (
      <div className="bg-yellow-50 dark:bg-yellow-900/30 border-b border-yellow-200 dark:border-yellow-700 px-4 py-2 text-center text-sm text-yellow-800 dark:text-yellow-200 flex flex-wrap items-center justify-center gap-2">
        <span>Подтвердите email — мы отправили письмо на <strong>{user.email}</strong></span>
        {resendingSent ? (
          <span className="text-yellow-600 dark:text-yellow-400 font-medium">Письмо отправлено!</span>
        ) : (
          <button
            onClick={handleResendVerification}
            className="underline font-medium hover:text-yellow-900 dark:hover:text-yellow-100 transition-colors"
          >
            Отправить повторно
          </button>
        )}
      </div>
    )}
    <nav className="sticky top-0 z-50 border-b border-gray-200 dark:border-gray-800 bg-white/90 dark:bg-gray-950/90 backdrop-blur-md">
      <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3">
        <Link href="/" className="text-xl font-bold text-brand-600 transition-opacity hover:opacity-80">
          Xabarla
        </Link>

        <div className="flex items-center gap-3">
          {user ? (
            <>
              <Link href="/" className="btn-ghost hidden sm:flex">
                <Home size={16} />
                {t.nav.authors}
              </Link>
              <Link href="/feed" className="btn-ghost hidden sm:flex">
                <Rss size={16} />
                {t.nav.feed}
              </Link>
              <Link href="/following" className="btn-ghost hidden sm:flex">
                <Heart size={16} />
                {t.nav.subscriptions}
              </Link>
              <Link href="/streams" className="btn-ghost hidden sm:flex">
                <Radio size={16} />
                {t.nav.streams}
              </Link>
              {(user.role === "creator" || user.role === "both") && (
                <Link href="/dashboard" className="btn-ghost hidden sm:flex">
                  <LayoutDashboard size={16} />
                  {t.nav.dashboard}
                </Link>
              )}

              {/* Язык */}
              <div className="relative hidden sm:block" ref={langRef}>
                <button
                  onClick={() => setLangOpen((v) => !v)}
                  className="btn-ghost p-2 gap-1 text-xs font-semibold"
                  aria-label="Язык"
                >
                  <Globe size={15} />
                  {locale.toUpperCase()}
                </button>
                {langOpen && (
                  <div className="absolute right-0 mt-2 w-24 rounded-xl border border-gray-100 dark:border-gray-700 bg-white dark:bg-gray-900 shadow-lg py-1">
                    {LOCALES.map((l) => (
                      <button
                        key={l.value}
                        onClick={() => { setLocale(l.value); setLangOpen(false); }}
                        className={`w-full px-4 py-2 text-sm text-left hover:bg-gray-50 dark:hover:bg-gray-800 ${locale === l.value ? "font-bold text-brand-600" : ""}`}
                      >
                        {l.label}
                      </button>
                    ))}
                  </div>
                )}
              </div>

              <button
                onClick={toggleTheme}
                className="btn-ghost p-2"
                aria-label="Переключить тему"
              >
                {theme === "dark" ? <Sun size={18} /> : <Moon size={18} />}
              </button>

              <NotificationBell />

              <div className="relative" ref={menuRef}>
                <button
                  onClick={() => setMenuOpen((v) => !v)}
                  className="flex items-center gap-2 rounded-full border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 py-1 pl-1 pr-3 transition-all hover:shadow-md"
                >
                  {user.avatar_url ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={user.avatar_url}
                      alt={user.username}
                      className="h-7 w-7 rounded-full object-cover"
                    />
                  ) : (
                    <div className="flex h-7 w-7 items-center justify-center rounded-full bg-brand-100 text-sm font-semibold text-brand-600">
                      {user.username[0].toUpperCase()}
                    </div>
                  )}
                  <span className="hidden text-sm font-medium sm:block">{user.username}</span>
                </button>

                {/* Dropdown */}
                <div
                  className={`absolute right-0 mt-2 w-52 origin-top-right transition-all duration-150 ${
                    menuOpen
                      ? "scale-100 opacity-100 pointer-events-auto"
                      : "scale-95 opacity-0 pointer-events-none"
                  }`}
                >
                  <div className="card py-1 shadow-lg">
                    <div className="border-b dark:border-gray-700 px-4 py-2">
                      <p className="text-sm font-medium">{user.username}</p>
                      <p className="text-xs text-gray-400">{user.email}</p>
                    </div>
                    <Link
                      href="/profile"
                      className="flex items-center gap-2 px-4 py-2 text-sm transition-colors hover:bg-gray-50 dark:hover:bg-gray-800"
                    >
                      <User size={14} />
                      {t.nav.profile}
                    </Link>
                    <Link
                      href="/billing"
                      className="flex items-center gap-2 px-4 py-2 text-sm transition-colors hover:bg-gray-50 dark:hover:bg-gray-800"
                    >
                      <CreditCard size={14} />
                      {t.nav.paymentHistory}
                    </Link>
                    <Link
                      href="/"
                      className="flex items-center gap-2 px-4 py-2 text-sm transition-colors hover:bg-gray-50 dark:hover:bg-gray-800 sm:hidden"
                    >
                      <Home size={14} />
                      {t.nav.authors}
                    </Link>
                    <Link
                      href="/feed"
                      className="flex items-center gap-2 px-4 py-2 text-sm transition-colors hover:bg-gray-50 dark:hover:bg-gray-800 sm:hidden"
                    >
                      <Rss size={14} />
                      {t.nav.feed}
                    </Link>
                    <Link
                      href="/following"
                      className="flex items-center gap-2 px-4 py-2 text-sm transition-colors hover:bg-gray-50 dark:hover:bg-gray-800 sm:hidden"
                    >
                      <Heart size={14} />
                      {t.nav.subscriptions}
                    </Link>
                    {(user.role === "creator" || user.role === "both") && (
                      <Link
                        href="/dashboard"
                        className="flex items-center gap-2 px-4 py-2 text-sm transition-colors hover:bg-gray-50 dark:hover:bg-gray-800 sm:hidden"
                      >
                        <LayoutDashboard size={14} />
                        {t.nav.dashboard}
                      </Link>
                    )}
                    {/* Язык в мобильном меню */}
                    <div className="sm:hidden border-t dark:border-gray-700 px-4 py-2">
                      <p className="text-xs text-gray-400 mb-1">Язык / Language</p>
                      <div className="flex gap-2">
                        {LOCALES.map((l) => (
                          <button
                            key={l.value}
                            onClick={() => setLocale(l.value)}
                            className={`px-2 py-1 text-xs rounded-md ${locale === l.value ? "bg-brand-600 text-white" : "bg-gray-100 dark:bg-gray-800"}`}
                          >
                            {l.label}
                          </button>
                        ))}
                      </div>
                    </div>
                    <hr className="my-1 dark:border-gray-700" />
                    <button
                      onClick={toggleTheme}
                      className="flex w-full items-center gap-2 px-4 py-2 text-sm transition-colors hover:bg-gray-50 dark:hover:bg-gray-800 sm:hidden"
                    >
                      {theme === "dark" ? <Sun size={14} /> : <Moon size={14} />}
                      {theme === "dark" ? t.nav.lightTheme : t.nav.darkTheme}
                    </button>
                    <hr className="my-1 dark:border-gray-700" />
                    <button
                      onClick={handleLogout}
                      className="flex w-full items-center gap-2 px-4 py-2 text-sm text-red-600 transition-colors hover:bg-red-50 dark:hover:bg-red-950"
                    >
                      <LogOut size={14} />
                      {t.nav.logout}
                    </button>
                  </div>
                </div>
              </div>
            </>
          ) : (
            <>
              {/* Язык для неавторизованных */}
              <div className="relative" ref={langRef}>
                <button
                  onClick={() => setLangOpen((v) => !v)}
                  className="btn-ghost p-2 gap-1 text-xs font-semibold"
                >
                  <Globe size={15} />
                  {locale.toUpperCase()}
                </button>
                {langOpen && (
                  <div className="absolute right-0 mt-2 w-24 rounded-xl border border-gray-100 dark:border-gray-700 bg-white dark:bg-gray-900 shadow-lg py-1">
                    {LOCALES.map((l) => (
                      <button
                        key={l.value}
                        onClick={() => { setLocale(l.value); setLangOpen(false); }}
                        className={`w-full px-4 py-2 text-sm text-left hover:bg-gray-50 dark:hover:bg-gray-800 ${locale === l.value ? "font-bold text-brand-600" : ""}`}
                      >
                        {l.label}
                      </button>
                    ))}
                  </div>
                )}
              </div>
              <button
                onClick={toggleTheme}
                className="btn-ghost p-2"
                aria-label="Переключить тему"
              >
                {theme === "dark" ? <Sun size={18} /> : <Moon size={18} />}
              </button>
              <Link href="/login" className="btn-outline">
                {t.nav.login}
              </Link>
              <Link href="/register" className="btn-primary">
                {t.nav.register}
              </Link>
            </>
          )}
        </div>
      </div>
    </nav>
    </>
  );
}
