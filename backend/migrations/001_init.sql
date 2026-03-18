CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE user_role AS ENUM ('patron', 'creator', 'both');
CREATE TYPE subscription_status AS ENUM ('active', 'cancelled', 'expired');
CREATE TYPE post_type AS ENUM ('text', 'image', 'video', 'audio');

CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username    VARCHAR(50) UNIQUE NOT NULL,
    email       VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role        user_role NOT NULL DEFAULT 'patron',
    avatar_url  TEXT,
    bio         TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE creator_profiles (
    id                       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    display_name             VARCHAR(100) NOT NULL,
    description              TEXT,
    cover_url                TEXT,
    category                 VARCHAR(50),
    subscription_price_cents INTEGER NOT NULL DEFAULT 0,
    subscription_description TEXT,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id)
);

CREATE TABLE subscriptions (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patron_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    creator_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status      subscription_status NOT NULL DEFAULT 'active',
    started_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ends_at     TIMESTAMPTZ,
    UNIQUE(patron_id, creator_id)
);

CREATE TABLE follows (
    follower_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    creator_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (follower_id, creator_id)
);

CREATE TABLE posts (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    creator_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title        VARCHAR(300) NOT NULL,
    content      TEXT,
    type         post_type NOT NULL DEFAULT 'text',
    is_free      BOOLEAN NOT NULL DEFAULT false,
    is_published BOOLEAN NOT NULL DEFAULT false,
    published_at TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE post_attachments (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id    UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    url        TEXT NOT NULL,
    mime_type  VARCHAR(100),
    size_bytes BIGINT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE comments (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id    UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    parent_id  UUID REFERENCES comments(id) ON DELETE CASCADE,
    content    TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE likes (
    post_id    UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);

CREATE TABLE refresh_tokens (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- indexes
CREATE INDEX idx_posts_creator_id ON posts(creator_id);
CREATE INDEX idx_posts_published_at ON posts(published_at DESC) WHERE is_published = true;
CREATE INDEX idx_subscriptions_patron_id ON subscriptions(patron_id);
CREATE INDEX idx_subscriptions_creator_id ON subscriptions(creator_id);
CREATE INDEX idx_comments_post_id ON comments(post_id);
CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
