"use client";

import { useQuery } from "@tanstack/react-query";
import { billingApi } from "@/lib/api";
import { BillingSubscription, BillingDonation } from "@/lib/types";
import { useAuth } from "@/hooks/useAuth";
import { useRouter, usePathname, useSearchParams } from "next/navigation";
import { useEffect } from "react";
import Link from "next/link";
import { CreditCard, Gift, Calendar, CheckCircle, XCircle, Clock } from "lucide-react";
import { useT } from "@/hooks/useT";

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString("ru-RU", {
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

function formatAmount(tenge: number) {
  return `${tenge.toLocaleString("ru-RU")} ₸`;
}

function StatusBadge({ status, t }: { status: string; t: ReturnType<typeof useT> }) {
  if (status === "active") {
    return (
      <span className="inline-flex items-center gap-1 rounded-full bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400 px-2 py-0.5 text-xs font-medium">
        <CheckCircle size={11} />
        {t.billing.active}
      </span>
    );
  }
  if (status === "cancelled") {
    return (
      <span className="inline-flex items-center gap-1 rounded-full bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300 px-2 py-0.5 text-xs font-medium">
        <XCircle size={11} />
        {t.billing.cancelled}
      </span>
    );
  }
  return (
    <span className="inline-flex items-center gap-1 rounded-full bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-400 px-2 py-0.5 text-xs font-medium">
      <Clock size={11} />
      {t.billing.expired}
    </span>
  );
}

export default function BillingPage() {
  const { user, isLoading: authLoading } = useAuth();
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const t = useT();

  const tab = (searchParams.get("tab") ?? "subscriptions") as "subscriptions" | "donations";
  const setTab = (next: "subscriptions" | "donations") => {
    const p = new URLSearchParams(searchParams.toString());
    p.set("tab", next);
    router.replace(`${pathname}?${p.toString()}`);
  };

  useEffect(() => {
    if (!authLoading && !user) router.push("/login");
  }, [user, authLoading, router]);

  const { data, isLoading } = useQuery({
    queryKey: ["billing"],
    queryFn: () => billingApi.history().then((r) => r.data.data as { subscriptions: BillingSubscription[]; donations: BillingDonation[] }),
    enabled: !!user,
  });

  const subscriptions = data?.subscriptions ?? [];
  const donations = data?.donations ?? [];

  return (
    <div className="mx-auto max-w-3xl px-4 py-10">
      <h1 className="mb-6 text-2xl font-bold flex items-center gap-2">
        <CreditCard size={24} className="text-brand-600" />
        {t.billing.title}
      </h1>

      {/* Табы */}
      <div className="mb-6 flex gap-1 rounded-xl bg-gray-100 dark:bg-gray-800 p-1">
        <button
          onClick={() => setTab("subscriptions")}
          className={`flex-1 rounded-lg py-2 text-sm font-medium transition-all ${
            tab === "subscriptions"
              ? "bg-white dark:bg-gray-900 shadow text-brand-600"
              : "text-gray-500 hover:text-gray-700 dark:hover:text-gray-300"
          }`}
        >
          <CreditCard size={14} className="inline mr-1.5" />
          {t.billing.subscriptions}
          {subscriptions.length > 0 && (
            <span className="ml-1.5 rounded-full bg-brand-100 dark:bg-brand-900/30 text-brand-600 px-1.5 py-0.5 text-xs">
              {subscriptions.length}
            </span>
          )}
        </button>
        <button
          onClick={() => setTab("donations")}
          className={`flex-1 rounded-lg py-2 text-sm font-medium transition-all ${
            tab === "donations"
              ? "bg-white dark:bg-gray-900 shadow text-brand-600"
              : "text-gray-500 hover:text-gray-700 dark:hover:text-gray-300"
          }`}
        >
          <Gift size={14} className="inline mr-1.5" />
          {t.billing.donations}
          {donations.length > 0 && (
            <span className="ml-1.5 rounded-full bg-brand-100 dark:bg-brand-900/30 text-brand-600 px-1.5 py-0.5 text-xs">
              {donations.length}
            </span>
          )}
        </button>
      </div>

      {isLoading ? (
        <div className="space-y-3">
          {[1, 2, 3].map((i) => (
            <div key={i} className="h-20 animate-pulse rounded-xl bg-gray-100 dark:bg-gray-800" />
          ))}
        </div>
      ) : tab === "subscriptions" ? (
        subscriptions.length === 0 ? (
          <div className="card p-12 text-center text-gray-400">
            <CreditCard size={40} className="mx-auto mb-3 opacity-30" />
            <p>{t.billing.noSubscriptions}</p>
          </div>
        ) : (
          <div className="space-y-3">
            {subscriptions.map((sub) => (
              <div key={sub.id} className="card p-4 flex items-center gap-4">
                {sub.creator_avatar ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={sub.creator_avatar} alt={sub.creator_name} className="h-12 w-12 rounded-full object-cover shrink-0" />
                ) : (
                  <div className="flex h-12 w-12 items-center justify-center rounded-full bg-brand-100 text-lg font-bold text-brand-600 shrink-0">
                    {sub.creator_name[0].toUpperCase()}
                  </div>
                )}
                <div className="flex-1 min-w-0">
                  <Link href={`/${sub.creator_username}`} className="font-semibold hover:text-brand-600 transition-colors">
                    {sub.creator_name}
                  </Link>
                  <p className="text-xs text-gray-400">@{sub.creator_username}</p>
                  <div className="mt-1 flex flex-wrap items-center gap-3 text-xs text-gray-500 dark:text-gray-400">
                    <span className="flex items-center gap-1">
                      <Calendar size={11} />
                      {t.billing.date}: {formatDate(sub.started_at)}
                    </span>
                    {sub.ends_at && (
                      <span className="flex items-center gap-1">
                        <Clock size={11} />
                        {t.billing.expiresAt}: {formatDate(sub.ends_at)}
                      </span>
                    )}
                    {sub.price_cents > 0 && (
                      <span className="font-medium text-gray-700 dark:text-gray-300">
                        {formatAmount(sub.price_cents)} {t.billing.perMonth}
                      </span>
                    )}
                  </div>
                </div>
                <StatusBadge status={sub.status} t={t} />
              </div>
            ))}
          </div>
        )
      ) : (
        donations.length === 0 ? (
          <div className="card p-12 text-center text-gray-400">
            <Gift size={40} className="mx-auto mb-3 opacity-30" />
            <p>{t.billing.noDonations}</p>
          </div>
        ) : (
          <div className="space-y-3">
            {donations.map((d) => (
              <div key={d.id} className="card p-4 flex items-center gap-4">
                {d.creator_avatar ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={d.creator_avatar} alt={d.creator_name} className="h-12 w-12 rounded-full object-cover shrink-0" />
                ) : (
                  <div className="flex h-12 w-12 items-center justify-center rounded-full bg-brand-100 text-lg font-bold text-brand-600 shrink-0">
                    {d.creator_name[0].toUpperCase()}
                  </div>
                )}
                <div className="flex-1 min-w-0">
                  <Link href={`/${d.creator_username}`} className="font-semibold hover:text-brand-600 transition-colors">
                    {d.creator_name}
                  </Link>
                  <p className="text-xs text-gray-400">@{d.creator_username}</p>
                  {d.message && (
                    <p className="mt-1 text-xs text-gray-500 dark:text-gray-400 italic truncate">
                      &ldquo;{d.message}&rdquo;
                    </p>
                  )}
                  <p className="mt-1 text-xs text-gray-400 flex items-center gap-1">
                    <Calendar size={11} />
                    {formatDate(d.created_at)}
                  </p>
                </div>
                <span className="shrink-0 font-bold text-brand-600 text-sm">
                  {formatAmount(d.amount_cents)}
                </span>
              </div>
            ))}
          </div>
        )
      )}
    </div>
  );
}
