# Xabarla — Subscription-Based Content Platform

A Patreon-style platform where creators publish content and earn through paid
subscriptions and donations, with a web app, a Flutter mobile app, live
streaming, realtime notifications, and personalized recommendations.

Multi-language out of the box: **English, Russian, Kazakh**.

---

## Features

- **Creators & patrons** — follow creators for free, or subscribe (free or paid) for access to gated content.
- **Posts** — rich text plus image / video / audio / PDF attachments; free or paid (locked) posts, pinning, likes, nested comments, view counts.
- **Payments** — paid subscriptions and one-off donations via **Stripe Checkout**.
- **Live streaming** — WebRTC broadcasting & viewing via **LiveKit**, with realtime chat and optional location-on-map. Stream from the web; watch on web or mobile.
- **Realtime notifications** — Server-Sent Events for new comments, subscribers, followers, donations, and "creator went live".
- **Recommendations** — content embeddings (multilingual sentence-transformers) stored in **Milvus** for a personalized feed.
- **Auth** — JWT access/refresh tokens, email verification.

## Architecture

Monorepo with four deployable apps plus shared infrastructure:

| Path | Stack | Role |
|------|-------|------|
| `backend/` | Go 1.25, chi, pgx (PostgreSQL), golang-jwt, Stripe, LiveKit JWT, SSE | REST API + realtime hub |
| `frontend/` | Next.js 14, React 18, TypeScript, Tailwind, TanStack Query, Zustand, `@livekit/components-react` | Web app |
| `subscription_app/` | Flutter (Dart), `livekit_client`, `video_player`/`chewie`, `flutter_secure_storage` | Mobile app (Android/iOS) |
| `embedding_service/` | Python, FastAPI, `sentence-transformers` (`paraphrase-multilingual-MiniLM-L12-v2`) | Generates content vectors for recommendations |

Supporting infrastructure (via Docker): **PostgreSQL**, **MinIO** (object storage for media), **Milvus** + **etcd** (vector search), **Mailpit** (dev SMTP), and **LiveKit** (streaming — LiveKit Cloud in this setup).

```
.
├── backend/              # Go API
│   ├── cmd/server/       # entrypoint
│   ├── internal/         # handlers, service, repository, middleware, hub (SSE), models
│   └── migrations/       # SQL migrations (applied on startup)
├── frontend/             # Next.js web app
├── subscription_app/     # Flutter mobile app
├── embedding_service/    # FastAPI embedding microservice
├── nginx/                # production reverse-proxy config
├── scripts/deploy.sh     # deployment helper
├── docker-compose.yml    # local dev infrastructure
└── docker-compose.prod.yml
```

---

## Getting started (local development)

### Prerequisites

- [Docker](https://www.docker.com/) & Docker Compose
- [Go](https://go.dev/) 1.25+
- [Node.js](https://nodejs.org/) 18+
- [Flutter](https://flutter.dev/) SDK (for the mobile app)

### 1. Start the infrastructure

```bash
cp .env.example .env          # optional — sensible defaults are baked in
docker compose up -d          # Postgres, MinIO, Milvus, embedding-service, Mailpit
```

| Service | URL / Port |
|---------|------------|
| PostgreSQL | `localhost:5433` |
| MinIO (API / console) | `localhost:9000` / `localhost:9001` |
| Milvus | `localhost:19530` |
| Embedding service | `localhost:8001` |
| Mailpit (web UI) | http://localhost:8025 |

### 2. Run the backend

```bash
cd backend
cp .env.example .env          # then fill in the values below
go run ./cmd/server           # serves the API on :8080 (/api)
```

Migrations in `backend/migrations/` are applied automatically on startup.

### 3. Run the web frontend

```bash
cd frontend
npm install
echo "NEXT_PUBLIC_API_URL=http://localhost:8080/api" > .env.local
npm run dev                   # http://localhost:3000
```

### 4. Run the mobile app

```bash
cd subscription_app
flutter pub get
flutter run                   # on an Android emulator, the API is auto-targeted at 10.0.2.2:8080
```

For a physical device / release, point it at a reachable **HTTPS** backend:

```bash
flutter build apk --release --dart-define=BASE_URL=https://<your-api-domain>/api
# output: build/app/outputs/flutter-apk/app-release.apk
```

---

## Environment variables (`backend/.env`)

```ini
DATABASE_URL=postgres://postgres:postgres@localhost:5433/diploma?sslmode=disable
JWT_SECRET=change-me-to-a-long-random-string
PORT=8080

# MinIO object storage
MINIO_ENDPOINT=localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_BUCKET=media
MINIO_PUBLIC_URL=http://localhost:9000

# Stripe (test keys)
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=

# LiveKit (streaming) — use a LiveKit Cloud project; required for video/chat to work
LIVEKIT_URL=wss://<your-project>.livekit.cloud
LIVEKIT_API_KEY=...
LIVEKIT_API_SECRET=...

FRONTEND_URL=http://localhost:3000
```

> **Note on streaming:** WebRTC media needs a reachable LiveKit server. A local
> LiveKit container does not work reliably behind Docker Desktop on Windows
> (UDP/NAT), so the recommended setup is a free **LiveKit Cloud** project — it
> handles ICE/TURN for web, emulator, and physical devices alike.

---

## Production

`docker-compose.prod.yml` builds and runs the backend, embedding service,
PostgreSQL, MinIO, and an **nginx** reverse proxy (TLS terminated there, e.g.
via certbot). Set production values in `backend/.env.prod` (including real
`LIVEKIT_*` and Stripe keys) before deploying:

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

---

## License

Released under the [MIT License](LICENSE).
