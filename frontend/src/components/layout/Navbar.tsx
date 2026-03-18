"use client";

import Link from "next/link";
import { useAuth } from "@/hooks/useAuth";
import { authApi } from "@/lib/api";
import { getTokens } from "@/lib/auth";
import { useRouter } from "next/navigation";
import { User, LayoutDashboard, LogOut, Rss } from "lucide-react";
import { useState } from "react";

export function Navbar() {
  const { user, logout } = useAuth();
  const router = useRouter();
  const [menuOpen, setMenuOpen] = useState(false);

  const handleLogout = async () => {
    const { refreshToken } = getTokens();
    if (refreshToken) {
      await authApi.logout(refreshToken).catch(() => {});
    }
    logout();
    router.push("/");
  };

  return (
    <nav className="sticky top-0 z-50 border-b border-gray-200 bg-white">
      <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3">
        <Link href="/" className="text-xl font-bold text-brand-600">
          Platform
        </Link>

        <div className="flex items-center gap-3">
          {user ? (
            <>
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

              <div className="relative">
                <button
                  onClick={() => setMenuOpen(!menuOpen)}
                  className="flex items-center gap-2 rounded-full p-1 hover:bg-gray-100"
                >
                  {user.avatar_url ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={user.avatar_url}
                      alt={user.username}
                      className="h-8 w-8 rounded-full object-cover"
                    />
                  ) : (
                    <div className="flex h-8 w-8 items-center justify-center rounded-full bg-brand-100 text-brand-600">
                      <User size={16} />
                    </div>
                  )}
                </button>

                {menuOpen && (
                  <div className="absolute right-0 mt-2 w-48 card py-1 shadow-lg">
                    <Link
                      href={`/${user.username}`}
                      className="flex items-center gap-2 px-4 py-2 text-sm hover:bg-gray-50"
                      onClick={() => setMenuOpen(false)}
                    >
                      <User size={14} />
                      Мой профиль
                    </Link>
                    <Link
                      href="/feed"
                      className="flex items-center gap-2 px-4 py-2 text-sm hover:bg-gray-50 sm:hidden"
                      onClick={() => setMenuOpen(false)}
                    >
                      <Rss size={14} />
                      Лента
                    </Link>
                    {(user.role === "creator" || user.role === "both") && (
                      <Link
                        href="/dashboard"
                        className="flex items-center gap-2 px-4 py-2 text-sm hover:bg-gray-50 sm:hidden"
                        onClick={() => setMenuOpen(false)}
                      >
                        <LayoutDashboard size={14} />
                        Кабинет
                      </Link>
                    )}
                    <hr className="my-1" />
                    <button
                      onClick={handleLogout}
                      className="flex w-full items-center gap-2 px-4 py-2 text-sm text-red-600 hover:bg-gray-50"
                    >
                      <LogOut size={14} />
                      Выйти
                    </button>
                  </div>
                )}
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
  );
}
