-- Migration 008: live streams with location

CREATE TABLE IF NOT EXISTS streams (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id   UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title        TEXT        NOT NULL DEFAULT '',
    status       TEXT        NOT NULL DEFAULT 'offline' CHECK (status IN ('live', 'ended')),
    latitude     DOUBLE PRECISION,
    longitude    DOUBLE PRECISION,
    livekit_room TEXT        NOT NULL,
    viewer_count INT         NOT NULL DEFAULT 0,
    started_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS streams_status_idx ON streams (status);
CREATE INDEX IF NOT EXISTS streams_creator_idx ON streams (creator_id);
