"use client";

import { create } from "zustand";
import { type Locale } from "@/locales";

interface LocaleState {
  locale: Locale;
  setLocale: (locale: Locale) => void;
}

export const useLocaleStore = create<LocaleState>()((set) => ({
  locale: "ru",
  setLocale: (locale) => {
    if (typeof localStorage !== "undefined") {
      localStorage.setItem("locale", locale);
    }
    set({ locale });
  },
}));
