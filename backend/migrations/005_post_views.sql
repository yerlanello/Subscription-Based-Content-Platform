CREATE TABLE IF NOT EXISTS post_views (
    user_id   UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    post_id   UUID        NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_post_views_user ON post_views(user_id);
CREATE INDEX IF NOT EXISTS idx_post_views_post ON post_views(post_id);
