-- Migration 009: chat messages for live streams
CREATE TABLE IF NOT EXISTS stream_messages (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    stream_id    UUID        NOT NULL REFERENCES streams(id) ON DELETE CASCADE,
    user_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    username     TEXT        NOT NULL,
    display_name TEXT        NOT NULL,
    message      TEXT        NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS stream_messages_stream_idx ON stream_messages (stream_id, created_at);
