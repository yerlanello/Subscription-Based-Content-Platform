package repository

import (
	"context"
	"time"

	"diploma/backend/internal/models"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type StreamRepo struct {
	db *pgxpool.Pool
}

func NewStreamRepo(db *pgxpool.Pool) *StreamRepo {
	return &StreamRepo{db: db}
}

func (r *StreamRepo) Create(ctx context.Context, creatorID uuid.UUID, title, room string) (*models.Stream, error) {
	s := &models.Stream{}
	err := r.db.QueryRow(ctx, `
		INSERT INTO streams (creator_id, title, livekit_room, status)
		VALUES ($1, $2, $3, 'live')
		RETURNING id, creator_id, title, status, latitude, longitude, livekit_room, viewer_count, started_at, ended_at
	`, creatorID, title, room).Scan(
		&s.ID, &s.CreatorID, &s.Title, &s.Status,
		&s.Latitude, &s.Longitude, &s.LivekitRoom,
		&s.ViewerCount, &s.StartedAt, &s.EndedAt,
	)
	return s, err
}

func (r *StreamRepo) End(ctx context.Context, streamID, creatorID uuid.UUID) error {
	now := time.Now()
	_, err := r.db.Exec(ctx, `
		UPDATE streams SET status = 'ended', ended_at = $1
		WHERE id = $2 AND creator_id = $3 AND status = 'live'
	`, now, streamID, creatorID)
	return err
}

func (r *StreamRepo) UpdateLocation(ctx context.Context, streamID, creatorID uuid.UUID, lat, lng float64) error {
	_, err := r.db.Exec(ctx, `
		UPDATE streams SET latitude = $1, longitude = $2
		WHERE id = $3 AND creator_id = $4 AND status = 'live'
	`, lat, lng, streamID, creatorID)
	return err
}

func (r *StreamRepo) ListLive(ctx context.Context) ([]models.Stream, error) {
	rows, err := r.db.Query(ctx, `
		SELECT s.id, s.creator_id, s.title, s.status,
		       s.latitude, s.longitude, s.livekit_room,
		       s.viewer_count, s.started_at, s.ended_at,
		       u.username,
		       COALESCE(cp.display_name, u.username),
		       u.avatar_url
		FROM streams s
		JOIN users u ON u.id = s.creator_id
		LEFT JOIN creator_profiles cp ON cp.user_id = s.creator_id
		WHERE s.status = 'live'
		ORDER BY s.started_at DESC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var streams []models.Stream
	for rows.Next() {
		var s models.Stream
		if err := rows.Scan(
			&s.ID, &s.CreatorID, &s.Title, &s.Status,
			&s.Latitude, &s.Longitude, &s.LivekitRoom,
			&s.ViewerCount, &s.StartedAt, &s.EndedAt,
			&s.Username, &s.DisplayName, &s.AvatarURL,
		); err != nil {
			return nil, err
		}
		streams = append(streams, s)
	}
	return streams, nil
}

func (r *StreamRepo) GetByID(ctx context.Context, id uuid.UUID) (*models.Stream, error) {
	s := &models.Stream{}
	err := r.db.QueryRow(ctx, `
		SELECT s.id, s.creator_id, s.title, s.status,
		       s.latitude, s.longitude, s.livekit_room,
		       s.viewer_count, s.started_at, s.ended_at,
		       u.username,
		       COALESCE(cp.display_name, u.username),
		       u.avatar_url
		FROM streams s
		JOIN users u ON u.id = s.creator_id
		LEFT JOIN creator_profiles cp ON cp.user_id = s.creator_id
		WHERE s.id = $1
	`, id).Scan(
		&s.ID, &s.CreatorID, &s.Title, &s.Status,
		&s.Latitude, &s.Longitude, &s.LivekitRoom,
		&s.ViewerCount, &s.StartedAt, &s.EndedAt,
		&s.Username, &s.DisplayName, &s.AvatarURL,
	)
	return s, err
}

func (r *StreamRepo) EndAllByCreator(ctx context.Context, creatorID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `
		UPDATE streams SET status = 'ended', ended_at = NOW()
		WHERE creator_id = $1 AND status = 'live'
	`, creatorID)
	return err
}

// EndStale ends streams that have been live for more than 4 hours.
func (r *StreamRepo) EndStale(ctx context.Context) error {
	_, err := r.db.Exec(ctx, `
		UPDATE streams SET status = 'ended', ended_at = NOW()
		WHERE status = 'live' AND started_at < NOW() - INTERVAL '4 hours'
	`)
	return err
}

func (r *StreamRepo) GetActiveByUsername(ctx context.Context, username string) (*models.Stream, error) {
	s := &models.Stream{}
	err := r.db.QueryRow(ctx, `
		SELECT s.id, s.creator_id, s.title, s.status,
		       s.latitude, s.longitude, s.livekit_room,
		       s.viewer_count, s.started_at, s.ended_at,
		       u.username,
		       COALESCE(cp.display_name, u.username),
		       u.avatar_url
		FROM streams s
		JOIN users u ON u.id = s.creator_id
		LEFT JOIN creator_profiles cp ON cp.user_id = s.creator_id
		WHERE u.username = $1 AND s.status = 'live'
		LIMIT 1
	`, username).Scan(
		&s.ID, &s.CreatorID, &s.Title, &s.Status,
		&s.Latitude, &s.Longitude, &s.LivekitRoom,
		&s.ViewerCount, &s.StartedAt, &s.EndedAt,
		&s.Username, &s.DisplayName, &s.AvatarURL,
	)
	return s, err
}

func (r *StreamRepo) SaveMessage(ctx context.Context, streamID, userID uuid.UUID, username, displayName, message string) (*models.StreamMessage, error) {
	m := &models.StreamMessage{}
	err := r.db.QueryRow(ctx, `
		INSERT INTO stream_messages (stream_id, user_id, username, display_name, message)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, stream_id, user_id, username, display_name, message, created_at
	`, streamID, userID, username, displayName, message).Scan(
		&m.ID, &m.StreamID, &m.UserID, &m.Username, &m.DisplayName, &m.Message, &m.CreatedAt,
	)
	return m, err
}

func (r *StreamRepo) GetMessages(ctx context.Context, streamID uuid.UUID) ([]models.StreamMessage, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, stream_id, user_id, username, display_name, message, created_at
		FROM stream_messages
		WHERE stream_id = $1
		ORDER BY created_at ASC
		LIMIT 500
	`, streamID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var msgs []models.StreamMessage
	for rows.Next() {
		var m models.StreamMessage
		if err := rows.Scan(&m.ID, &m.StreamID, &m.UserID, &m.Username, &m.DisplayName, &m.Message, &m.CreatedAt); err != nil {
			return nil, err
		}
		msgs = append(msgs, m)
	}
	if msgs == nil {
		msgs = []models.StreamMessage{}
	}
	return msgs, nil
}

func (r *StreamRepo) GetActiveByCreator(ctx context.Context, creatorID uuid.UUID) (*models.Stream, error) {
	s := &models.Stream{}
	err := r.db.QueryRow(ctx, `
		SELECT id, creator_id, title, status, latitude, longitude,
		       livekit_room, viewer_count, started_at, ended_at
		FROM streams WHERE creator_id = $1 AND status = 'live' LIMIT 1
	`, creatorID).Scan(
		&s.ID, &s.CreatorID, &s.Title, &s.Status,
		&s.Latitude, &s.Longitude, &s.LivekitRoom,
		&s.ViewerCount, &s.StartedAt, &s.EndedAt,
	)
	if err != nil {
		return nil, err
	}
	return s, nil
}
