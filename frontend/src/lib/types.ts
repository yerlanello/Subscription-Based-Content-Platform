export type UserRole = "patron" | "creator" | "both";
export type SubscriptionStatus = "active" | "cancelled" | "expired";
export type PostType = "text" | "image" | "video" | "audio";

export interface User {
  id: string;
  username: string;
  email?: string;
  role: UserRole;
  avatar_url: string | null;
  bio: string | null;
  created_at: string;
  updated_at: string;
}

export interface PublicUser {
  id: string;
  username: string;
  avatar_url: string | null;
}

export interface CreatorProfile {
  id: string;
  user_id: string;
  display_name: string;
  description: string | null;
  cover_url: string | null;
  category: string | null;
  subscription_price_cents: number;
  subscription_description: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreatorPage {
  user: User;
  profile: CreatorProfile;
  is_subscribed: boolean;
  is_following: boolean;
}

export interface CreatorWithProfile {
  user: User;
  profile: CreatorProfile;
}

export interface PostAttachment {
  id: string;
  post_id: string;
  url: string;
  mime_type: string | null;
  size_bytes: number | null;
  created_at: string;
}

export interface Post {
  id: string;
  creator_id: string;
  title: string;
  content: string | null;
  type: PostType;
  is_free: boolean;
  is_published: boolean;
  published_at: string | null;
  created_at: string;
  updated_at: string;
  attachments?: PostAttachment[];
  likes_count?: number;
  is_liked?: boolean;
  creator?: PublicUser;
}

export interface Comment {
  id: string;
  post_id: string;
  user_id: string;
  parent_id: string | null;
  content: string;
  created_at: string;
  updated_at: string;
  author?: PublicUser;
  replies?: Comment[];
}

export interface Subscription {
  id: string;
  patron_id: string;
  creator_id: string;
  status: SubscriptionStatus;
  started_at: string;
  ends_at: string | null;
}
