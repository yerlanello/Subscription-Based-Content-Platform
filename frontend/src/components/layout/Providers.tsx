"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";
import { AuthInitializer } from "./AuthInitializer";
import { SplashScreen } from "./SplashScreen";
import { useAuthStore } from "@/store/authStore";

function AppShell({ children }: { children: React.ReactNode }) {
  const isLoading = useAuthStore((s) => s.isLoading);
  if (isLoading) return <SplashScreen />;
  return <>{children}</>;
}

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: { queries: { staleTime: 60 * 1000 } },
      })
  );

  return (
    <QueryClientProvider client={queryClient}>
      <AuthInitializer />
      <AppShell>{children}</AppShell>
    </QueryClientProvider>
  );
}
