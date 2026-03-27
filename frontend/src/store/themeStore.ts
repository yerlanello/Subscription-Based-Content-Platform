"use client";

import { create } from "zustand";

type Theme = "light" | "dark";

interface ThemeState {
  theme: Theme;
  toggleTheme: () => void;
  _syncFromDOM: () => void;
}

export const useThemeStore = create<ThemeState>((set, get) => ({
  theme: "light",

  // Читает реальный класс на <html> и синхронизирует store
  _syncFromDOM: () => {
    if (typeof document === "undefined") return;
    const isDark = document.documentElement.classList.contains("dark");
    set({ theme: isDark ? "dark" : "light" });
  },

  toggleTheme: () => {
    const newTheme = get().theme === "light" ? "dark" : "light";
    if (typeof document !== "undefined") {
      document.documentElement.classList.toggle("dark", newTheme === "dark");
      localStorage.setItem("theme", newTheme);
    }
    set({ theme: newTheme });
  },
}));
