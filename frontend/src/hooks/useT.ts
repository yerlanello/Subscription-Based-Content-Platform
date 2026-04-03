import { useLocaleStore } from "@/store/localeStore";
import { translations } from "@/locales";

export function useT() {
  const locale = useLocaleStore((s) => s.locale);
  return translations[locale];
}
