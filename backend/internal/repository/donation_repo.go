package repository

import (
	"context"

	"diploma/backend/internal/models"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type DonationRepo struct {
	db *pgxpool.Pool
}

func NewDonationRepo(db *pgxpool.Pool) *DonationRepo {
	return &DonationRepo{db: db}
}

func (r *DonationRepo) Create(ctx context.Context, donorID, creatorID uuid.UUID, amountCents int, message *string, sessionID *string) (*models.Donation, error) {
	d := &models.Donation{}
	err := r.db.QueryRow(ctx, `
		INSERT INTO donations (donor_id, creator_id, amount_cents, message, stripe_session_id)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, donor_id, creator_id, amount_cents, message, stripe_session_id, created_at
	`, donorID, creatorID, amountCents, message, sessionID).Scan(
		&d.ID, &d.DonorID, &d.CreatorID, &d.AmountCents, &d.Message, &d.StripeSessionID, &d.CreatedAt,
	)
	return d, err
}

func (r *DonationRepo) ExistsBySessionID(ctx context.Context, sessionID string) (bool, error) {
	var exists bool
	err := r.db.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM donations WHERE stripe_session_id = $1)`, sessionID).Scan(&exists)
	return exists, err
}

func (r *DonationRepo) GetByCreator(ctx context.Context, creatorID uuid.UUID, limit, offset int) ([]models.Donation, error) {
	rows, err := r.db.Query(ctx, `
		SELECT d.id, d.donor_id, d.creator_id, d.amount_cents, d.message, d.stripe_session_id, d.created_at,
		       u.id, u.username, u.avatar_url
		FROM donations d
		JOIN users u ON u.id = d.donor_id
		WHERE d.creator_id = $1
		ORDER BY d.created_at DESC
		LIMIT $2 OFFSET $3
	`, creatorID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var donations []models.Donation
	for rows.Next() {
		var d models.Donation
		d.Donor = &models.PublicUser{}
		if err := rows.Scan(
			&d.ID, &d.DonorID, &d.CreatorID, &d.AmountCents, &d.Message, &d.StripeSessionID, &d.CreatedAt,
			&d.Donor.ID, &d.Donor.Username, &d.Donor.AvatarURL,
		); err != nil {
			return nil, err
		}
		donations = append(donations, d)
	}
	return donations, nil
}