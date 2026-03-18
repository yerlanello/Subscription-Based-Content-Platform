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
api.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const originalRequest = error.config as typeof error.config & {
      _retry?: boolean;
    };

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
};

// --- Users ---
export const usersApi = {
  me: () => api.get("/users/me"),
  updateMe: (data: { avatar_url?: string; bio?: string }) =>
    api.put("/users/me", data),
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
};

// --- Posts ---
export const postsApi = {
  feed: (params?: { limit?: number; offset?: number }) =>
    api.get("/posts/feed", { params }),
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
  delete: (id: string) => api.delete(`/posts/${id}`),
  like: (id: string) => api.post(`/posts/${id}/like`),
  unlike: (id: string) => api.delete(`/posts/${id}/like`),
  getComments: (id: string) => api.get(`/posts/${id}/comments`),
  createComment: (
    id: string,
    data: { content: string; parent_id?: string }
  ) => api.post(`/posts/${id}/comments`, data),
  deleteComment: (postId: string, commentId: string) =>
    api.delete(`/posts/${postId}/comments/${commentId}`),
};
