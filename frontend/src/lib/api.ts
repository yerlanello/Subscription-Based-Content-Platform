import axios, { AxiosError } from "axios";
import { getTokens, setTokens, clearTokens } from "./auth";

const BASE_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8080/api";

export const api = axios.create({
  baseURL: BASE_URL,
  headers: { "Content-Type": "application/json" },
});

// Добавляем access token к каждому запросу
api.interceptors.request.use((config) => {
  const { accessToken } = getTokens();
  if (accessToken) {
    config.headers.Authorization = `Bearer ${accessToken}`;
  }
  return config;
});

let isRefreshing = false;
let failedQueue: Array<{
  resolve: (value: unknown) => void;
  reject: (reason?: unknown) => void;
}> = [];

const processQueue = (error: unknown, token: string | null = null) => {
  failedQueue.forEach(({ resolve, reject }) => {
    if (error) reject(error);
    else resolve(token);
  });
  failedQueue = [];
};

// Автоматически обновляем токен при 401
// Auth endpoints where 401 is an expected response (wrong credentials),
// NOT a signal to refresh the token.
const AUTH_ENDPOINTS = ["/auth/login", "/auth/register", "/auth/refresh",
  "/auth/forgot-password", "/auth/reset-password", "/auth/verify-email"];

api.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const originalRequest = error.config as typeof error.config & {
      _retry?: boolean;
    };

    const url = originalRequest?.url ?? "";

    // 429 — rate limit hit
    if (error.response?.status === 429) {
      return Promise.reject(
        Object.assign(error, {
          response: {
            ...error.response,
            data: { error: "Слишком много попыток. Подождите немного и попробуйте снова." },
          },
        })
      );
    }

    // 401 on auth endpoints — just pass through (wrong password, etc.)
    if (error.response?.status === 401 && AUTH_ENDPOINTS.some((p) => url.includes(p))) {
      return Promise.reject(error);
    }

    // 401 on other endpoints — try to refresh the token
    if (error.response?.status === 401 && !originalRequest._retry) {
      if (isRefreshing) {
        return new Promise((resolve, reject) => {
          failedQueue.push({ resolve, reject });
        }).then((token) => {
          originalRequest.headers!.Authorization = `Bearer ${token}`;
          return api(originalRequest);
        });
      }

      originalRequest._retry = true;
      isRefreshing = true;

      const { refreshToken } = getTokens();
      if (!refreshToken) {
        clearTokens();
        return Promise.reject(error);
      }

      try {
        const { data } = await axios.post(`${BASE_URL}/auth/refresh`, {
          refresh_token: refreshToken,
        });
        const { access_token, refresh_token } = data.data;
        setTokens(access_token, refresh_token);
        processQueue(null, access_token);
        originalRequest.headers!.Authorization = `Bearer ${access_token}`;
        return api(originalRequest);
      } catch (refreshError) {
        processQueue(refreshError, null);
        clearTokens();
        window.location.href = "/login";
        return Promise.reject(refreshError);
      } finally {
        isRefreshing = false;
      }
    }

    return Promise.reject(error);
  }
);

// --- Auth ---
export const authApi = {
  register: (data: { username: string; email: string; password: string }) =>
    api.post("/auth/register", data),
  login: (data: { email: string; password: string }) =>
    api.post("/auth/login", data),
  logout: (refreshToken: string) =>
    api.delete("/auth/logout", { data: { refresh_token: refreshToken } }),
  verifyEmail: (token: string) =>
    api.post("/auth/verify-email", { token }),
  resendVerification: () =>
    api.post("/auth/resend-verification"),
  forgotPassword: (email: string) =>
    api.post("/auth/forgot-password", { email }),
  resetPassword: (token: string, password: string) =>
    api.post("/auth/reset-password", { token, password }),
};

// --- Users ---
export const usersApi = {
  me: () => api.get("/users/me"),
  updateMe: (data: { avatar_url?: string; bio?: string }) =>
    api.put("/users/me", data),
  uploadAvatar: (formData: FormData) =>
    api.post("/users/me/avatar", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    }),
  getByUsername: (username: string) => api.get(`/users/${username}`),
  mySubscriptions: () => api.get("/users/me/subscriptions"),
};

// --- Creators ---
export const creatorsApi = {
  list: (params?: { limit?: number; offset?: number; category?: string }) =>
    api.get("/creators", { params }),
  getByUsername: (username: string) => api.get(`/creators/${username}`),
  becomeCreator: (data: { display_name: string }) =>
    api.post("/creators", data),
  updateProfile: (
    username: string,
    data: {
      display_name?: string;
      description?: string;
      cover_url?: string;
      category?: string;
      subscription_price_cents?: number;
      subscription_description?: string;
    }
  ) => api.put(`/creators/${username}`, data),
  subscribe: (username: string) =>
    api.post(`/creators/${username}/subscribe`),
  unsubscribe: (username: string) =>
    api.delete(`/creators/${username}/subscribe`),
  follow: (username: string) => api.post(`/creators/${username}/follow`),
  unfollow: (username: string) => api.delete(`/creators/${username}/follow`),
  getPosts: (username: string, params?: { limit?: number; offset?: number }) =>
    api.get(`/creators/${username}/posts`, { params }),
  createCheckout: (username: string) =>
    api.post<{ data: { url: string } }>(`/creators/${username}/checkout`),
  uploadCover: (username: string, formData: FormData) =>
    api.post(`/creators/${username}/cover`, formData, {
      headers: { "Content-Type": "multipart/form-data" },
    }),
};

// --- Subscriptions ---
export const subscriptionsApi = {
  verifySession: (sessionId: string) =>
    api.post("/subscriptions/verify-session", { session_id: sessionId }),
};

// --- Donations ---
export const donationsApi = {
  createCheckout: (username: string, data: { amount_cents: number; message?: string }) =>
    api.post<{ data: { url: string } }>(`/creators/${username}/donate`, data),
  verify: (sessionId: string) =>
    api.post("/donations/verify", { session_id: sessionId }),
};

// --- Following ---
export const followingApi = {
  myFollowing: () => api.get("/users/me/following"),
};

// --- Billing ---
export const billingApi = {
  history: () => api.get("/users/me/billing"),
};

// --- Notifications ---
export const notificationsApi = {
  list: () => api.get("/notifications"),
  markAllRead: () => api.post("/notifications/read-all"),
  markRead: (id: string) => api.post(`/notifications/${id}/read`),
  delete: (id: string) => api.delete(`/notifications/${id}`),
  deleteAll: () => api.delete("/notifications"),
};

// --- Posts ---
export const postsApi = {
  feed: (params?: { limit?: number; offset?: number }) =>
    api.get("/posts/feed", { params }),
  explore: (params?: { limit?: number; offset?: number }) =>
    api.get("/posts/explore", { params }),
  recommended: (params?: { limit?: number; offset?: number }) =>
    api.get("/posts/recommended", { params }),
  get: (id: string) => api.get(`/posts/${id}`),
  create: (data: {
    title: string;
    content?: string;
    type?: string;
    is_free?: boolean;
  }) => api.post("/posts", data),
  update: (
    id: string,
    data: { title?: string; content?: string; is_free?: boolean }
  ) => api.put(`/posts/${id}`, data),
  publish: (id: string) => api.post(`/posts/${id}/publish`),
  unpublish: (id: string) => api.post(`/posts/${id}/unpublish`),
  delete: (id: string) => api.delete(`/posts/${id}`),
  uploadAttachment: (id: string, formData: FormData) =>
    api.post(`/posts/${id}/attachments`, formData, {
      headers: { "Content-Type": "multipart/form-data" },
    }),
  deleteAttachment: (postId: string, attachmentId: string) =>
    api.delete(`/posts/${postId}/attachments/${attachmentId}`),
  like: (id: string) => api.post(`/posts/${id}/like`),
  unlike: (id: string) => api.delete(`/posts/${id}/like`),
  getComments: (id: string) => api.get(`/posts/${id}/comments`),
  createComment: (
    id: string,
    data: { content: string; parent_id?: string }
  ) => api.post(`/posts/${id}/comments`, data),
  deleteComment: (postId: string, commentId: string) =>
    api.delete(`/posts/${postId}/comments/${commentId}`),
  likeComment: (postId: string, commentId: string) =>
    api.post(`/posts/${postId}/comments/${commentId}/like`),
  unlikeComment: (postId: string, commentId: string) =>
    api.delete(`/posts/${postId}/comments/${commentId}/like`),
  pin: (id: string) => api.post(`/posts/${id}/pin`),
  unpin: (id: string) => api.delete(`/posts/${id}/pin`),
};

export const streamsApi = {
  list: () => api.get("/streams"),
  get: (id: string) => api.get(`/streams/${id}`),
  getMine: () => api.get("/streams/my"),
  getByCreator: (username: string) => api.get(`/streams/by-creator/${username}`),
  start: (title: string) => api.post("/streams/start", { title }),
  end: (id: string) => api.post(`/streams/${id}/end`),
  join: (id: string) => api.post(`/streams/${id}/join`),
  updateLocation: (id: string, latitude: number, longitude: number) =>
    api.patch(`/streams/${id}/location`, { latitude, longitude }),
  getMessages: (id: string) => api.get(`/streams/${id}/messages`),
  sendMessage: (id: string, message: string, display_name: string) =>
    api.post(`/streams/${id}/messages`, { message, display_name }),
};
