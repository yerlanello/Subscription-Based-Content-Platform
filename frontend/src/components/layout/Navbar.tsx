"use client";

import Link from "next/link";
import { useAuth } from "@/hooks/useAuth";
import { authApi } from "@/lib/api";
import { getTokens } from "@/lib/auth";
import { useRouter, usePathname } from "next/navigation";
import { User, LayoutDashboard, LogOut, Rss, Home } from "lucide-react";
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
    <nav className="sticky top-0 z-50 border-b border-gray-200 bg-white/80 backdrop-blur-md">
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
              {(user.role === "creator" || user.role === "both") && (
                <Link href="/dashboard" className="btn-ghost hidden sm:flex">
                  <LayoutDashboard size={16} />
                  Кабинет
                </Link>
              )}

              <NotificationBell />

              <div className="relative" ref={menuRef}>
                <button
                  onClick={() => setMenuOpen((v) => !v)}
                  className="flex items-center gap-2 rounded-full border border-gray-200 py-1 pl-1 pr-3 transition-all hover:shadow-md"
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
                    <div className="border-b px-4 py-2">
                      <p className="text-sm font-medium">{user.username}</p>
                      <p className="text-xs text-gray-400">{user.email}</p>
                    </div>
                    <Link
                      href="/profile"
                      className="flex items-center gap-2 px-4 py-2 text-sm transition-colors hover:bg-gray-50"
                    >
                      <User size={14} />
                      Мой профиль
                    </Link>
                    <Link
                      href="/"
                      className="flex items-center gap-2 px-4 py-2 text-sm transition-colors hover:bg-gray-50 sm:hidden"
                    >
                      <Home size={14} />
                      Авторы
                    </Link>
                    <Link
                      href="/feed"
                      className="flex items-center gap-2 px-4 py-2 text-sm transition-colors hover:bg-gray-50 sm:hidden"
                    >
                      <Rss size={14} />
                      Лента
                    </Link>
                    {(user.role === "creator" || user.role === "both") && (
                      <Link
                        href="/dashboard"
                        className="flex items-center gap-2 px-4 py-2 text-sm transition-colors hover:bg-gray-50 sm:hidden"
                      >
                        <LayoutDashboard size={14} />
                        Кабинет
                      </Link>
                    )}
                    <hr className="my-1" />
                    <button
                      onClick={handleLogout}
                      className="flex w-full items-center gap-2 px-4 py-2 text-sm text-red-600 transition-colors hover:bg-red-50"
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
