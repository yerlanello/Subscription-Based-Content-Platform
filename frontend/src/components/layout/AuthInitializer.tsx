"use client";

import { useAuthInit } from "@/hooks/useAuth";

export function AuthInitializer() {
  useAuthInit();
  return null;
}
