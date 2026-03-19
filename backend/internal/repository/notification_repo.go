package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Notification struct {
	ID        uuid.UUID `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	Type      string    `json:"type"`
	Title     string    `json:"title"`
	Body      *string   `json:"body"`
	Link      *string   `json:"link"`
	IsRead    bool      `json:"is_read"`
	CreatedAt time.Time `json:"created_at"`
}

type NotificationRepo struct {
	db *pgxpool.Pool
}

func NewNotificationRepo(db *pgxpool.Pool) *NotificationRepo {
	return &NotificationRepo{db: db}
}

func (r *NotificationRepo) Create(ctx context.Context, userID uuid.UUID, notifType, title string, body, link *string) (*Notification, error) {
	n := &Notification{}
	err := r.db.QueryRow(ctx, `
		INSERT INTO notifications (user_id, type, title, body, link)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, user_id, type, title, body, link, is_read, created_at
	`, userID, notifType, title, body, link).Scan(
		&n.ID, &n.UserID, &n.Type, &n.Title, &n.Body, &n.Link, &n.IsRead, &n.CreatedAt,
	)
	return n, err
}

// GetByUser — последние уведомления пользователя
func (r *NotificationRepo) GetByUser(ctx context.Context, userID uuid.UUID, limit int) ([]Notification, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, user_id, type, title, body, link, is_read, created_at
		FROM notifications WHERE user_id = $1
		ORDER BY created_at DESC LIMIT $2
	`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []Notification
	for rows.Next() {
		var n Notification
		if err := rows.Scan(&n.ID, &n.UserID, &n.Type, &n.Title, &n.Body, &n.Link, &n.IsRead, &n.CreatedAt); err != nil {
			return nil, err
		}
		result = append(result, n)
	}
	return result, nil
}

// UnreadCount — количество непрочитанных
func (r *NotificationRepo) UnreadCount(ctx context.Context, userID uuid.UUID) (int, error) {
	var count int
	err := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = FALSE`, userID).Scan(&count)
	return count, err
}

// MarkAllRead — отметить все прочитанными
func (r *NotificationRepo) MarkAllRead(ctx context.Context, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `UPDATE notifications SET is_read = TRUE WHERE user_id = $1`, userID)
	return err
}

// MarkRead — отметить одно уведомление прочитанным
func (r *NotificationRepo) MarkRead(ctx context.Context, id, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `UPDATE notifications SET is_read = TRUE WHERE id = $1 AND user_id = $2`, id, userID)
	return err
}

// Delete — удалить одно уведомление
func (r *NotificationRepo) Delete(ctx context.Context, id, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM notifications WHERE id = $1 AND user_id = $2`, id, userID)
	return err
}

// DeleteAll — удалить все уведомления пользователя
func (r *NotificationRepo) DeleteAll(ctx context.Context, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM notifications WHERE user_id = $1`, userID)
	return err
}

// GetFollowerAndSubscriberIDs — все кто подписан или следит за автором
func (r *NotificationRepo) GetFollowerAndSubscriberIDs(ctx context.Context, creatorID uuid.UUID) ([]uuid.UUID, error) {
	rows, err := r.db.Query(ctx, `
		SELECT DISTINCT user_id FROM (
			SELECT patron_id AS user_id FROM subscriptions WHERE creator_id = $1 AND status = 'active'
			UNION
			SELECT follower_id AS user_id FROM follows WHERE creator_id = $1
		) t WHERE user_id != $1
	`, creatorID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var ids []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, nil
}
