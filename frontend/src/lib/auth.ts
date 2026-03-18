const ACCESS_KEY = "access_token";
const REFRESH_KEY = "refresh_token";

export function getTokens() {
  if (typeof window === "undefined")
    return { accessToken: null, refreshToken: null };
  return {
    accessToken: localStorage.getItem(ACCESS_KEY),
    refreshToken: localStorage.getItem(REFRESH_KEY),
  };
}

export function setTokens(accessToken: string, refreshToken: string) {
  localStorage.setItem(ACCESS_KEY, accessToken);
  localStorage.setItem(REFRESH_KEY, refreshToken);
}

export function clearTokens() {
  localStorage.removeItem(ACCESS_KEY);
  localStorage.removeItem(REFRESH_KEY);
}

export function formatPrice(cents: number): string {
  if (cents === 0) return "Бесплатно";
  return `${(cents / 100).toFixed(0)} ₸/мес`;
}
