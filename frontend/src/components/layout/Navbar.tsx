"use client";

import Link from "next/link";
import { useAuth } from "@/hooks/useAuth";
import { authApi } from "@/lib/api";
import { getTokens } from "@/lib/auth";
import { useRouter, usePathname } from "next/navigation";
import { User, LayoutDashboard, LogOut, Rss, Home, Moon, Sun, Heart } from "lucide-react";
import { useState, useEffect, useRef } from "react";
import { NotificationBell } from "./NotificationBell";
import { NotificationToasts } from "./NotificationToasts";
import { useSSENotifications } from "@/hooks/useNotifications";

export function Navbar() {
  const { user, logout } = useAuth();
  const router = useRouter();
  const pathname = usePathname();
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const { toasts, dismissToast } = useSSENotifications(!!user);
  const [isDark, setIsDark] = useState(false);

  useEffect(() => {
    setIsDark(document.documentElement.classList.contains("dark"));
  }, []);

  const toggleTheme = () => {
    // читаем из DOM напрямую, не из state (чтобы не было stale closure)
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
  }, [pathname]);

  // Закрываем при клике вне меню
  useEffect(() => {
    if (!menuOpen) return;
    const handleClick = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setMenuOpen(false);
      }
    };
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [menuOpen]);

  const handleLogout = async () => {
    const { refreshToken } = getTokens();
    if (refreshToken) {
      await authApi.logout(refreshToken).catch(() => {});
    }
    logout();
    router.push("/");
  };

  return (
    <>
    <NotificationToasts toasts={toasts} onDismiss={dismissToast} />
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
                Авторы
              </Link>
              <Link href="/feed" className="btn-ghost hidden sm:flex">
                <Rss size={16} />
                Лента
              </Link>
              <Link href="/following" className="btn-ghost hidden sm:flex">
                <Heart size={16} />
                Подписки
              </Link>
              {(user.role === "creator" || user.role === "both") && (
                <Link href="/dashboard" className="btn-ghost hidden sm:flex">
                  <LayoutDashboard size={16} />
                  Кабинет
                </Link>
              )}

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
                      Мой профиль
                    </Link>
                    <Link
                      href="/"
                      className="flex items-center gap-2 px-4 py-2 text-sm transition-colors hover:bg-gray-50 dark:hover:bg-gray-800 sm:hidden"
                    >
                      <Home size={14} />
                      Авторы
                    </Link>
                    <Link
                      href="/feed"
                      className="flex items-center gap-2 px-4 py-2 text-sm transition-colors hover:bg-gray-50 dark:hover:bg-gray-800 sm:hidden"
                    >
                      <Rss size={14} />
                      Лента
                    </Link>
                    <Link
                      href="/following"
                      className="flex items-center gap-2 px-4 py-2 text-sm transition-colors hover:bg-gray-50 dark:hover:bg-gray-800 sm:hidden"
                    >
                      <Heart size={14} />
                      Подписки
                    </Link>
                    {(user.role === "creator" || user.role === "both") && (
                      <Link
                        href="/dashboard"
                        className="flex items-center gap-2 px-4 py-2 text-sm transition-colors hover:bg-gray-50 dark:hover:bg-gray-800 sm:hidden"
                      >
                        <LayoutDashboard size={14} />
                        Кабинет
                      </Link>
                    )}
                    <hr className="my-1 dark:border-gray-700" />
                    <button
                      onClick={toggleTheme}
                      className="flex w-full items-center gap-2 px-4 py-2 text-sm transition-colors hover:bg-gray-50 dark:hover:bg-gray-800 sm:hidden"
                    >
                      {theme === "dark" ? <Sun size={14} /> : <Moon size={14} />}
                      {theme === "dark" ? "Светлая тема" : "Тёмная тема"}
                    </button>
                    <hr className="my-1 dark:border-gray-700" />
                    <button
                      onClick={handleLogout}
                      className="flex w-full items-center gap-2 px-4 py-2 text-sm text-red-600 transition-colors hover:bg-red-50 dark:hover:bg-red-950"
                    >
                      <LogOut size={14} />
                      Выйти
                    </button>
                  </div>
                </div>
              </div>
            </>
          ) : (
            <>
              <button
                onClick={toggleTheme}
                className="btn-ghost p-2"
                aria-label="Переключить тему"
              >
                {theme === "dark" ? <Sun size={18} /> : <Moon size={18} />}
              </button>
              <Link href="/login" className="btn-outline">
                Войти
              </Link>
              <Link href="/register" className="btn-primary">
                Регистрация
              </Link>
            </>
          )}
        </div>
      </div>
    </nav>
    </>
  );
}
