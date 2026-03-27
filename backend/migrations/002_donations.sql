CREATE TABLE donations (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    donor_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    creator_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount_cents      INTEGER NOT NULL,
    message           TEXT,
    stripe_session_id TEXT UNIQUE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_donations_creator_id ON donations(creator_id);
CREATE INDEX idx_donations_donor_id ON donations(donor_id);