"use client";

import { create } from "zustand";
import { User } from "@/lib/types";
import { setTokens, clearTokens } from "@/lib/auth";

interface AuthState {
  user: User | null;
  isLoading: boolean;
  setUser: (user: User | null) => void;
  login: (user: User, accessToken: string, refreshToken: string) => void;
  logout: () => void;
  setLoading: (v: boolean) => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  isLoading: true,
  setUser: (user) => set({ user }),
  login: (user, accessToken, refreshToken) => {
    setTokens(accessToken, refreshToken);
    set({ user });
  },
  logout: () => {
    clearTokens();
    set({ user: null });
  },
  setLoading: (v) => set({ isLoading: v }),
}));
