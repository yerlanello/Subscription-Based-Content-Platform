"use client";

import { useEffect } from "react";
import { useAuthStore } from "@/store/authStore";
import { usersApi } from "@/lib/api";
import { getTokens } from "@/lib/auth";

export function useAuthInit() {
  const { setUser, setLoading } = useAuthStore();

  useEffect(() => {
    const { accessToken } = getTokens();
    if (!accessToken) {
      setLoading(false);
      return;
    }
    usersApi
      .me()
      .then((res) => setUser(res.data.data))
      .catch(() => setUser(null))
      .finally(() => setLoading(false));
  }, [setUser, setLoading]);
}

export function useAuth() {
  return useAuthStore();
}
