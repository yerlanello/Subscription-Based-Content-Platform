"use client";

import { useLayoutEffect } from "react";
import { useThemeStore } from "@/store/themeStore";

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const _syncFromDOM = useThemeStore((s) => s._syncFromDOM);

  // useLayoutEffect — запускается синхронно до отрисовки, иконка не мигает
  useLayoutEffect(() => {
    // Применяем тему из localStorage/системных настроек
    const saved = localStorage.getItem("theme");
    if (saved !== "dark" && saved !== "light") {
      // Первый визит — определяем по системным настройкам
      const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
      document.documentElement.classList.toggle("dark", prefersDark);
      localStorage.setItem("theme", prefersDark ? "dark" : "light");
    }
    // Синхронизируем store с реальным DOM-состоянием
    _syncFromDOM();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  return <>{children}</>;
}
