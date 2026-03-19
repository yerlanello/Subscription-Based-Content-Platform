package models

import (
	"time"

	"github.com/google/uuid"
)

type UserRole string
type SubscriptionStatus string
type PostType string

const (
	RolePatron  UserRole = "patron"
	RoleCreator UserRole = "creator"
	RoleBoth    UserRole = "both"

	StatusActive    SubscriptionStatus = "active"
	StatusCancelled SubscriptionStatus = "cancelled"
	StatusExpired   SubscriptionStatus = "expired"

	PostTypeText  PostType = "text"
	PostTypeImage PostType = "image"
	PostTypeVideo PostType = "video"
	PostTypeAudio PostType = "audio"
)

type User struct {
	ID           uuid.UUID `json:"id"`
	Username     string    `json:"username"`
	Email        string    `json:"email,omitempty"`
	PasswordHash string    `json:"-"`
	Role         UserRole  `json:"role"`
	AvatarURL    *string   `json:"avatar_url"`
	Bio          *string   `json:"bio"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

type CreatorProfile struct {
	ID                      uuid.UUID `json:"id"`
	UserID                  uuid.UUID `json:"user_id"`
	DisplayName             string    `json:"display_name"`
	Description             *string   `json:"description"`
	CoverURL                *string   `json:"cover_url"`
	Category                *string   `json:"category"`
	SubscriptionPriceCents  int       `json:"subscription_price_cents"`
	SubscriptionDescription *string   `json:"subscription_description"`
	CreatedAt               time.Time `json:"created_at"`
	UpdatedAt               time.Time `json:"updated_at"`
}

type CreatorWithProfile struct {
	User    User           `json:"user"`
	Profile CreatorProfile `json:"profile"`
}

type Subscription struct {
	ID        uuid.UUID          `json:"id"`
	PatronID  uuid.UUID          `json:"patron_id"`
	CreatorID uuid.UUID          `json:"creator_id"`
	Status    SubscriptionStatus `json:"status"`
	StartedAt time.Time          `json:"started_at"`
	EndsAt    *time.Time         `json:"ends_at"`
}

type Follow struct {
	FollowerID uuid.UUID `json:"follower_id"`
	CreatorID  uuid.UUID `json:"creator_id"`
	CreatedAt  time.Time `json:"created_at"`
}

type Post struct {
	ID          uuid.UUID  `json:"id"`
	CreatorID   uuid.UUID  `json:"creator_id"`
	Title       string     `json:"title"`
	Content     *string    `json:"content"`
	Type        PostType   `json:"type"`
	IsFree      bool       `json:"is_free"`
	IsPublished bool       `json:"is_published"`
	PublishedAt *time.Time `json:"published_at"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`

	// Joined fields
	Attachments    []PostAttachment `json:"attachments,omitempty"`
	LikesCount     int              `json:"likes_count,omitempty"`
	CommentsCount  int              `json:"comments_count,omitempty"`
	IsLiked        bool             `json:"is_liked,omitempty"`
	Creator        *PublicUser      `json:"creator,omitempty"`
}

type PostAttachment struct {
	ID        uuid.UUID `json:"id"`
	PostID    uuid.UUID `json:"post_id"`
	URL       string    `json:"url"`
	MimeType  *string   `json:"mime_type"`
	SizeBytes *int64    `json:"size_bytes"`
	CreatedAt time.Time `json:"created_at"`
}

type Comment struct {
	ID        uuid.UUID  `json:"id"`
	PostID    uuid.UUID  `json:"post_id"`
	UserID    uuid.UUID  `json:"user_id"`
	ParentID  *uuid.UUID `json:"parent_id"`
	Content   string     `json:"content"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`

	// Joined
	Author   *PublicUser `json:"author,omitempty"`
	Replies  []Comment   `json:"replies,omitempty"`
}

type RefreshToken struct {
	ID        uuid.UUID `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	TokenHash string    `json:"-"`
	ExpiresAt time.Time `json:"expires_at"`
	CreatedAt time.Time `json:"created_at"`
}

// PublicUser — урезанный профиль для публичных ответов
type PublicUser struct {
	ID        uuid.UUID `json:"id"`
	Username  string    `json:"username"`
	AvatarURL *string   `json:"avatar_url"`
}
