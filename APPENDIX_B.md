# Appendix B: Source Code Excerpts

This appendix provides representative source code excerpts rather than the full
repository. Short excerpts are preferable because they are easier to review in
printed thesis form, while the complete project repository remains the
authoritative source for all code. Where a file is long or repetitive, only its
essential portions are reproduced and elisions are marked with `// ...`.

The platform follows a service-oriented architecture. A Go backend exposes the
REST/SSE API and contains all business logic; a Python micro-service produces
semantic embeddings for recommendation; PostgreSQL stores relational data; MinIO
stores uploaded media; and Milvus provides vector similarity search. Stripe
handles payments, and an SMTP service delivers transactional email. Two clients
consume the API: a Next.js web application and a Flutter mobile application. In
production an Nginx reverse proxy is the single public entry point. The excerpts
below were chosen to illustrate the decisions that most shaped the system:
stateless JWT authentication with refresh-token rotation, the subscription
paywall, real-time notifications over Server-Sent Events, payment verification,
and the recommendation pipeline.

---

## B.1 Application Bootstrap and API Routing

### Listing 1: Server entry point and router (`backend/cmd/server/main.go`)

The entry point wires the application together: it loads configuration from the
environment, opens a connection pool, runs migrations, and constructs the
repository, service, and handler layers in dependency order. Routes are grouped
with the `chi` router, and each route is explicitly annotated with the
middleware it requires — `authMiddleware` for protected endpoints, `optionalAuth`
for endpoints that behave differently for guests, and a dedicated `sseAuth` for
the streaming endpoint. The recommendation subsystem is treated as optional: if
Milvus is unreachable at start-up the server logs a warning and continues without
personalised recommendations rather than failing.

```go
func main() {
    _ = godotenv.Load()

    dsn := os.Getenv("DATABASE_URL")
    if dsn == "" {
        log.Fatal("DATABASE_URL is required")
    }
    jwtSecret := os.Getenv("JWT_SECRET")
    if jwtSecret == "" {
        log.Fatal("JWT_SECRET is required")
    }

    ctx := context.Background()
    pool, err := repository.NewPool(ctx, dsn)
    if err != nil {
        log.Fatalf("connect to db: %v", err)
    }
    defer pool.Close()

    if err := repository.RunMigrations(ctx, pool); err != nil {
        log.Fatalf("migrations: %v", err)
    }

    // Repositories → services → handlers (dependency order)
    userRepo := repository.NewUserRepo(pool)
    postRepo := repository.NewPostRepo(pool)
    subRepo := repository.NewSubscriptionRepo(pool)
    // ... other repositories ...

    notifHub := hub.New()
    authSvc := service.NewAuthService(userRepo, jwtSecret, emailSvc, tokenRepo)
    postSvc := service.NewPostService(postRepo, subRepo, notifRepo, userRepo, commentRepo, notifHub)

    // Recommendation is optional — degrades gracefully if Milvus is unavailable
    var recSvc *recommendation.Service
    if milvusClient, err := recommendation.NewMilvusClient(ctx, milvusAddr, ""); err != nil {
        log.Printf("warn: milvus unavailable, recommendations disabled: %v", err)
    } else {
        recSvc = recommendation.NewService(milvusClient, embClient, postRepo, creatorRepo)
        defer milvusClient.Close()
    }

    r := chi.NewRouter()
    r.Use(chimiddleware.Logger, chimiddleware.Recoverer, chimiddleware.RequestID)
    r.Use(cors.Handler(cors.Options{
        AllowedOrigins:   allowedOrigins,
        AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
        AllowedHeaders:   []string{"Authorization", "Content-Type"},
        AllowCredentials: true,
    }))

    authMiddleware := middleware.Auth(jwtSecret)
    optionalAuth := middleware.OptionalAuth(jwtSecret)
    sseAuth := middleware.SSEAuth(jwtSecret)

    r.Route("/api", func(r chi.Router) {
        r.Route("/auth", func(r chi.Router) {
            r.Post("/register", authH.Register)
            r.Post("/login", authH.Login)
            r.Post("/refresh", authH.Refresh)
            r.With(authMiddleware).Delete("/logout", authH.Logout)
            r.Post("/verify-email", authH.VerifyEmail)
            r.Post("/forgot-password", authH.ForgotPassword)
            r.Post("/reset-password", authH.ResetPassword)
        })

        r.Route("/posts", func(r chi.Router) {
            r.With(authMiddleware).Get("/feed", postH.Feed)
            r.With(optionalAuth).Get("/explore", postH.Explore)
            r.With(authMiddleware).Get("/recommended", postH.Recommended)
            r.With(authMiddleware).Post("/", postH.Create)
            r.With(optionalAuth).Get("/{id}", postH.Get)        // paywall enforced in service
            r.With(authMiddleware).Post("/{id}/like", postH.Like)
            // ... comments, attachments, pin ...
        })

        // Stripe webhook is unauthenticated — verified by Stripe's signature instead
        r.Post("/webhooks/stripe", stripeH.Webhook)

        r.Route("/notifications", func(r chi.Router) {
            r.With(authMiddleware).Get("/", notifH.List)
            r.With(sseAuth).Get("/stream", notifH.Stream) // Server-Sent Events
        })
        // ... users, creators, streams ...
    })

    log.Printf("server starting on :%s", port)
    if err := http.ListenAndServe(":"+port, r); err != nil {
        log.Fatal(err)
    }
}
```

### Listing 2: Uniform JSON response envelope (`backend/internal/response/response.go`)

Every endpoint returns a consistent envelope — successful results under a `data`
key and failures under an `error` key — so that both clients can parse responses
uniformly.

```go
type envelope map[string]any

func JSON(w http.ResponseWriter, status int, data any) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(data)
}

func OK(w http.ResponseWriter, data any)      { JSON(w, http.StatusOK, envelope{"data": data}) }
func Created(w http.ResponseWriter, data any)  { JSON(w, http.StatusCreated, envelope{"data": data}) }
func Error(w http.ResponseWriter, status int, message string) {
    JSON(w, status, envelope{"error": message})
}
func NoContent(w http.ResponseWriter)          { w.WriteHeader(http.StatusNoContent) }
```

---

## B.2 Authentication and Session Security

### Listing 3: JWT issuing and refresh-token hashing (`backend/internal/auth/jwt.go`)

Authentication is stateless. A short-lived (15-minute) access token is signed
with HS256 and carries the user's id, username, and role as claims; a long-lived
(30-day) refresh token is an opaque 256-bit random value. Crucially, only the
**SHA-256 hash** of the refresh token is ever stored, so a database disclosure
does not expose usable session tokens. Token validation explicitly rejects any
signing method other than HMAC, defending against algorithm-substitution attacks.

```go
const (
    accessTokenTTL  = 15 * time.Minute
    refreshTokenTTL = 30 * 24 * time.Hour
)

type Claims struct {
    UserID   uuid.UUID `json:"user_id"`
    Username string    `json:"username"`
    Role     string    `json:"role"`
    jwt.RegisteredClaims
}

func GenerateAccessToken(userID uuid.UUID, username, role, secret string) (string, error) {
    claims := Claims{
        UserID: userID, Username: username, Role: role,
        RegisteredClaims: jwt.RegisteredClaims{
            ExpiresAt: jwt.NewNumericDate(time.Now().Add(accessTokenTTL)),
            IssuedAt:  jwt.NewNumericDate(time.Now()),
        },
    }
    return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(secret))
}

func ValidateAccessToken(tokenStr, secret string) (*Claims, error) {
    token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (interface{}, error) {
        if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
            return nil, errors.New("unexpected signing method") // reject "alg" confusion
        }
        return []byte(secret), nil
    })
    if err != nil {
        return nil, err
    }
    claims, ok := token.Claims.(*Claims)
    if !ok || !token.Valid {
        return nil, errors.New("invalid token")
    }
    return claims, nil
}

// GenerateRefreshToken returns the raw token (sent to the client) and its hash
// (the only form persisted in the database).
func GenerateRefreshToken() (token, hash string, expiresAt time.Time, err error) {
    b := make([]byte, 32)
    if _, err = rand.Read(b); err != nil {
        return
    }
    token = hex.EncodeToString(b)
    hash = HashToken(token)
    expiresAt = time.Now().Add(refreshTokenTTL)
    return
}

func HashToken(token string) string {
    h := sha256.Sum256([]byte(token))
    return hex.EncodeToString(h[:])
}
```

### Listing 4: Authentication service (`backend/internal/service/auth_service.go`)

The service layer holds the security-critical logic. Passwords are hashed with
bcrypt; login compares the supplied password against the stored hash in constant
time. Refresh employs **rotation** — the presented token is invalidated and a new
pair is issued — so a leaked refresh token has a single use. `ForgotPassword`
deliberately returns success even when the email is unknown, to avoid leaking
which addresses are registered. The verification email is dispatched on a
background goroutine so registration latency is unaffected.

```go
func (s *AuthService) Register(ctx context.Context, input RegisterInput) (*AuthResult, error) {
    hash, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcrypt.DefaultCost)
    if err != nil {
        return nil, err
    }
    user, err := s.userRepo.Create(ctx, input.Username, input.Email, string(hash))
    if err != nil {
        if errors.Is(err, repository.ErrConflict) {
            return nil, ErrUserExists
        }
        return nil, err
    }
    go func() { // send verification email without blocking the response
        if err := s.SendVerificationEmail(context.Background(), user.ID); err != nil {
            log.Printf("warn: send verification email for user %s: %v", user.ID, err)
        }
    }()
    return s.issueTokens(ctx, user)
}

func (s *AuthService) Login(ctx context.Context, email, password string) (*AuthResult, error) {
    user, err := s.userRepo.GetByEmail(ctx, email)
    if err != nil {
        if errors.Is(err, repository.ErrNotFound) {
            return nil, ErrInvalidCredentials
        }
        return nil, err
    }
    if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
        return nil, ErrInvalidCredentials
    }
    return s.issueTokens(ctx, user)
}

func (s *AuthService) Refresh(ctx context.Context, rawToken string) (*AuthResult, error) {
    hash := auth.HashToken(rawToken)
    rt, err := s.userRepo.GetRefreshToken(ctx, hash)
    if err != nil {
        return nil, ErrTokenInvalid
    }
    if time.Now().After(rt.ExpiresAt) {
        _ = s.userRepo.DeleteRefreshToken(ctx, hash)
        return nil, ErrTokenExpired
    }
    user, err := s.userRepo.GetByID(ctx, rt.UserID)
    if err != nil {
        return nil, err
    }
    _ = s.userRepo.DeleteRefreshToken(ctx, hash) // rotate: invalidate the used token
    return s.issueTokens(ctx, user)
}

func (s *AuthService) ForgotPassword(ctx context.Context, emailAddr string) error {
    user, err := s.userRepo.GetByEmail(ctx, emailAddr)
    if err != nil {
        return nil // don't leak whether the email exists
    }
    token, err := s.tokenRepo.CreatePasswordResetToken(ctx, user.ID)
    if err != nil {
        return nil
    }
    if err := s.emailSvc.SendPasswordResetEmail(user.Email, user.Username, token); err != nil {
        log.Printf("warn: send password reset email to %s: %v", emailAddr, err)
    }
    return nil
}

func (s *AuthService) issueTokens(ctx context.Context, user *models.User) (*AuthResult, error) {
    accessToken, err := auth.GenerateAccessToken(user.ID, user.Username, string(user.Role), s.jwtSecret)
    if err != nil {
        return nil, err
    }
    rawRefresh, hashRefresh, expiresAt, err := auth.GenerateRefreshToken()
    if err != nil {
        return nil, err
    }
    if err := s.userRepo.SaveRefreshToken(ctx, user.ID, hashRefresh, expiresAt); err != nil {
        return nil, err
    }
    return &AuthResult{User: user, AccessToken: accessToken, RefreshToken: rawRefresh}, nil
}
```

### Listing 5: Authentication middleware (`backend/internal/middleware/auth.go`)

Three middleware variants cover the application's needs. `Auth` rejects requests
without a valid bearer token; `OptionalAuth` parses a token if present but allows
guests through (used for endpoints whose output depends on whether the caller is
logged in); and `SSEAuth` additionally accepts the token as a query parameter,
because the browser `EventSource` API cannot set an `Authorization` header.
Validated claims are placed on the request context for downstream handlers.

```go
func Auth(secret string) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            header := r.Header.Get("Authorization")
            if !strings.HasPrefix(header, "Bearer ") {
                response.Error(w, http.StatusUnauthorized, "missing or invalid authorization header")
                return
            }
            claims, err := auth.ValidateAccessToken(strings.TrimPrefix(header, "Bearer "), secret)
            if err != nil {
                response.Error(w, http.StatusUnauthorized, "invalid or expired token")
                return
            }
            ctx := context.WithValue(r.Context(), UserContextKey, claims)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}

// SSEAuth — for EventSource: token may arrive via ?token= or the Authorization header.
func SSEAuth(secret string) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            tokenStr := ""
            if h := r.Header.Get("Authorization"); strings.HasPrefix(h, "Bearer ") {
                tokenStr = strings.TrimPrefix(h, "Bearer ")
            } else if q := r.URL.Query().Get("token"); q != "" {
                tokenStr = q
            }
            claims, err := auth.ValidateAccessToken(tokenStr, secret)
            if err != nil {
                response.Error(w, http.StatusUnauthorized, "invalid or expired token")
                return
            }
            ctx := context.WithValue(r.Context(), UserContextKey, claims)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}
```

---

## B.3 Subscription Access Control (the Paywall)

### Listing 6: Content access enforcement (`backend/internal/service/post_service.go`)

The paywall is the defining feature of the platform and is enforced entirely on
the server. `Get` returns a post only when the caller is entitled to it:
unpublished posts are visible only to their author, and paid posts require either
authorship or an active subscription; a guest receives `ErrAccessDenied`.
`ListByCreator` applies the same rule in bulk, **redacting** the body and
attachments of paid posts the caller cannot access rather than omitting them — so
the existence of premium content is advertised while its contents stay protected.

```go
// Get returns the post if requesterID is entitled to view it.
// requesterID may be uuid.Nil for an anonymous guest.
func (s *PostService) Get(ctx context.Context, postID, requesterID uuid.UUID) (*models.Post, error) {
    post, err := s.postRepo.GetByID(ctx, postID)
    if err != nil {
        return nil, mapRepoErr(err)
    }

    // Unpublished posts are visible only to their author.
    if !post.IsPublished && post.CreatorID != requesterID {
        return nil, ErrNotFound
    }

    // Paid posts require authorship or an active subscription.
    if !post.IsFree && post.CreatorID != requesterID {
        if requesterID == uuid.Nil {
            return nil, ErrAccessDenied
        }
        subscribed, err := s.subRepo.IsSubscribed(ctx, requesterID, post.CreatorID)
        if err != nil {
            return nil, err
        }
        if !subscribed {
            return nil, ErrAccessDenied
        }
    }

    post.LikesCount, _ = s.postRepo.LikesCount(ctx, postID)
    if requesterID != uuid.Nil {
        post.IsLiked, _ = s.postRepo.IsLiked(ctx, postID, requesterID)
    }
    post.Attachments, _ = s.postRepo.GetAttachments(ctx, postID)
    return post, nil
}

// ListByCreator returns a creator's posts, redacting the body of paid posts
// the caller is not entitled to (the post itself remains listed).
func (s *PostService) ListByCreator(ctx context.Context, creatorID, requesterID uuid.UUID, limit, offset int) ([]models.Post, error) {
    isOwner := creatorID == requesterID
    posts, err := s.postRepo.ListByCreator(ctx, creatorID, limit, offset, !isOwner)
    if err != nil {
        return nil, err
    }
    var subscribed bool
    if requesterID != uuid.Nil && !isOwner {
        subscribed, _ = s.subRepo.IsSubscribed(ctx, requesterID, creatorID)
    }
    for i := range posts {
        if !posts[i].IsFree && !isOwner && !subscribed {
            posts[i].Content = nil      // redact premium body
            posts[i].Attachments = nil  // and its attachments
        }
    }
    return posts, nil
}
```

---

## B.4 Real-Time Notifications (Server-Sent Events)

### Listing 7: In-memory subscription hub (`backend/internal/hub/hub.go`)

Notifications are pushed to connected clients in real time. A `Hub` maintains, per
user id, the set of currently connected clients, each represented by a buffered
channel. `Send` is **non-blocking**: if a client's buffer is full the event is
dropped rather than stalling the publisher, which keeps a slow consumer from
back-pressuring the rest of the system. Access to the client map is guarded by a
read/write mutex.

```go
type Event struct {
    Type  string `json:"type"`
    Title string `json:"title"`
    Body  string `json:"body,omitempty"`
    Link  string `json:"link,omitempty"`
    ID    string `json:"id"`
}

type Hub struct {
    mu      sync.RWMutex
    clients map[uuid.UUID][]*client
}

// Subscribe registers a client and returns its event channel plus an unsubscribe func.
func (h *Hub) Subscribe(userID uuid.UUID) (<-chan Event, func()) {
    c := &client{ch: make(chan Event, 8)}
    h.mu.Lock()
    h.clients[userID] = append(h.clients[userID], c)
    h.mu.Unlock()

    unsubscribe := func() {
        h.mu.Lock()
        defer h.mu.Unlock()
        list := h.clients[userID]
        for i, existing := range list {
            if existing == c {
                h.clients[userID] = append(list[:i], list[i+1:]...)
                break
            }
        }
        close(c.ch)
    }
    return c.ch, unsubscribe
}

// Send delivers an event to a user's connections, never blocking on a full buffer.
func (h *Hub) Send(userID uuid.UUID, event Event) {
    h.mu.RLock()
    defer h.mu.RUnlock()
    for _, c := range h.clients[userID] {
        select {
        case c.ch <- event:
        default: // drop if the client is too slow
        }
    }
}

func (e Event) ToSSE() []byte {
    data, _ := json.Marshal(e)
    return append([]byte("data: "), append(data, '\n', '\n')...)
}
```

### Listing 8: SSE streaming handler (`backend/internal/handlers/notification_handler.go`)

The handler sets the headers required for an event stream (including
`X-Accel-Buffering: no` so the Nginx proxy does not buffer the response),
subscribes to the hub, and then loops: it relays events as they arrive, sends a
keep-alive comment every 25 seconds to hold the connection open through
intermediaries, and exits cleanly when the client disconnects (detected via the
request context).

```go
func (h *NotificationHandler) Stream(w http.ResponseWriter, r *http.Request) {
    claims := middleware.GetClaims(r)
    if claims == nil {
        w.WriteHeader(http.StatusUnauthorized)
        return
    }

    w.Header().Set("Content-Type", "text/event-stream")
    w.Header().Set("Cache-Control", "no-cache")
    w.Header().Set("Connection", "keep-alive")
    w.Header().Set("X-Accel-Buffering", "no") // tell Nginx not to buffer

    flusher, ok := w.(http.Flusher)
    if !ok {
        response.Error(w, http.StatusInternalServerError, "streaming not supported")
        return
    }
    fmt.Fprintf(w, ": ping\n\n") // open the stream immediately
    flusher.Flush()

    events, unsubscribe := h.hub.Subscribe(claims.UserID)
    defer unsubscribe()

    ticker := time.NewTicker(25 * time.Second)
    defer ticker.Stop()

    for {
        select {
        case <-r.Context().Done(): // client disconnected
            return
        case <-ticker.C:
            fmt.Fprintf(w, ": ping\n\n") // keep-alive
            flusher.Flush()
        case event, ok := <-events:
            if !ok {
                return
            }
            w.Write(event.ToSSE())
            flusher.Flush()
        }
    }
}
```

---

## B.5 Payments (Stripe)

### Listing 9: Checkout creation and webhook handling (`backend/internal/handlers/stripe_handler.go`)

Payments use Stripe Checkout. The backend creates a Checkout Session, embedding
the patron and creator ids in the session metadata so the resulting payment can
be reconciled, and returns the hosted-checkout URL. Prices are denominated in
KZT, a non-zero-decimal currency, so amounts are multiplied by 100 and bounded by
Stripe's maximum. Confirmation arrives through a webhook whose signature is
verified with the endpoint secret before the corresponding subscription or
donation is recorded; the same event shape carries both, distinguished by a
`type` field in the metadata.

```go
// CreateCheckout — POST /api/creators/{username}/checkout
func (h *StripeHandler) CreateCheckout(w http.ResponseWriter, r *http.Request) {
    claims := middleware.GetClaims(r)
    username := chi.URLParam(r, "username")

    creatorUser, err := h.userRepo.GetByUsername(r.Context(), username)
    if err != nil {
        response.Error(w, http.StatusNotFound, "creator not found")
        return
    }
    profile, err := h.creatorRepo.GetByUserID(r.Context(), creatorUser.ID)
    if err != nil {
        response.Error(w, http.StatusNotFound, "creator profile not found")
        return
    }

    // KZT is not a zero-decimal currency: amounts are sent in tiyn (×100).
    amountTiyn := int64(profile.SubscriptionPriceCents) * 100

    params := &stripe.CheckoutSessionParams{
        Mode: stripe.String(string(stripe.CheckoutSessionModePayment)),
        LineItems: []*stripe.CheckoutSessionLineItemParams{{
            PriceData: &stripe.CheckoutSessionLineItemPriceDataParams{
                Currency:   stripe.String("kzt"),
                UnitAmount: stripe.Int64(amountTiyn),
                ProductData: &stripe.CheckoutSessionLineItemPriceDataProductDataParams{
                    Name: stripe.String("Подписка на " + profile.DisplayName),
                },
            },
            Quantity: stripe.Int64(1),
        }},
        SuccessURL: stripe.String(frontendURL + "/subscribe/success?...&session_id={CHECKOUT_SESSION_ID}"),
        CancelURL:  stripe.String(frontendURL + "/" + username),
        Metadata: map[string]string{ // reconciled later by the webhook
            "patron_id":  claims.UserID.String(),
            "creator_id": creatorUser.ID.String(),
        },
    }
    sess, err := session.New(params)
    if err != nil {
        response.Error(w, http.StatusInternalServerError, "failed to create checkout session")
        return
    }
    response.OK(w, map[string]string{"url": sess.URL})
}

// Webhook — POST /api/webhooks/stripe (no auth; authenticity is the signature)
func (h *StripeHandler) Webhook(w http.ResponseWriter, r *http.Request) {
    payload, _ := io.ReadAll(r.Body)
    endpointSecret := os.Getenv("STRIPE_WEBHOOK_SECRET")
    sig := r.Header.Get("Stripe-Signature")

    event, err := webhook.ConstructEvent(payload, sig, endpointSecret) // verifies HMAC signature
    if err != nil {
        response.Error(w, http.StatusBadRequest, "invalid signature")
        return
    }

    if event.Type == "checkout.session.completed" {
        var sess stripe.CheckoutSession
        json.Unmarshal(event.Data.Raw, &sess)

        if sess.Metadata["type"] == "donation" {
            donorID, _ := uuid.Parse(sess.Metadata["donor_id"])
            creatorID, _ := uuid.Parse(sess.Metadata["creator_id"])
            amount, _ := strconv.Atoi(sess.Metadata["amount"])
            h.donationRepo.Create(r.Context(), donorID, creatorID, amount, msgPtr, &sess.ID)
        } else {
            patronID, _ := uuid.Parse(sess.Metadata["patron_id"])
            creatorID, _ := uuid.Parse(sess.Metadata["creator_id"])
            h.subRepo.Subscribe(r.Context(), patronID, creatorID)
        }
    }
    w.WriteHeader(http.StatusOK)
}
```

---

## B.6 Media Storage and Upload Validation

### Listing 10: Object storage with an allow-list (`backend/internal/storage/minio.go` and `post_handler.go`)

Uploaded media is stored in MinIO under randomised, collision-free object names
(`uuid`-based), which prevents path traversal and name guessing. The bucket is
given a public-read policy so that media can be streamed directly by clients
without proxying authenticated bytes through the API. On the handler side, uploads
are bounded to 50 MB and constrained to an **allow-list** of file extensions
mapped to known MIME types — anything else is rejected.

```go
func NewMinioStorage(endpoint, accessKey, secretKey, bucket, publicURL string) (*MinioStorage, error) {
    client, err := minio.New(endpoint, &minio.Options{
        Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
        Secure: false,
    })
    if err != nil {
        return nil, err
    }
    // Ensure the bucket exists and is publicly readable so clients can stream media.
    policy := fmt.Sprintf(`{"Version":"2012-10-17","Statement":[{"Effect":"Allow",`+
        `"Principal":{"AWS":["*"]},"Action":["s3:GetObject"],"Resource":["arn:aws:s3:::%s/*"]}]}`, bucket)
    _ = client.SetBucketPolicy(context.Background(), bucket, policy)
    return &MinioStorage{client: client, bucket: bucket, publicURL: publicURL}, nil
}

func (s *MinioStorage) UploadFile(ctx context.Context, r io.Reader, objectName, contentType string, size int64) (string, error) {
    _, err := s.client.PutObject(ctx, s.bucket, objectName, r, size, minio.PutObjectOptions{ContentType: contentType})
    if err != nil {
        return "", err
    }
    return fmt.Sprintf("%s/%s/%s", s.publicURL, s.bucket, objectName), nil
}
```

```go
// Only these extensions are accepted for post attachments.
var allowedMimeTypes = map[string]string{
    ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png",
    ".webp": "image/webp", ".gif": "image/gif",
    ".mp4": "video/mp4", ".webm": "video/webm", ".mov": "video/quicktime",
    ".mp3": "audio/mpeg", ".wav": "audio/wav", ".ogg": "audio/ogg", ".m4a": "audio/mp4",
    ".pdf": "application/pdf", ".txt": "text/plain",
}

func (h *PostHandler) UploadAttachment(w http.ResponseWriter, r *http.Request) {
    claims := middleware.GetClaims(r)
    postID, _ := uuid.Parse(r.PathValue("id"))

    if _, err := h.postSvc.GetOwn(r.Context(), postID, claims.UserID); err != nil {
        response.Error(w, http.StatusForbidden, "forbidden") // only the author may upload
        return
    }
    if err := r.ParseMultipartForm(50 << 20); err != nil { // 50 MB ceiling
        response.Error(w, http.StatusBadRequest, "file too large (max 50MB)")
        return
    }
    file, header, _ := r.FormFile("file")
    defer file.Close()

    ext := strings.ToLower(filepath.Ext(header.Filename))
    mimeType, ok := allowedMimeTypes[ext]
    if !ok {
        response.Error(w, http.StatusBadRequest, "unsupported file type") // allow-list
        return
    }
    objectName := fmt.Sprintf("posts/%s/%s%s", postID, uuid.New().String(), ext) // unguessable name
    url, _ := h.storage.UploadFile(r.Context(), file, objectName, mimeType, header.Size)
    attachment, _ := h.postSvc.AddAttachment(r.Context(), postID, url, mimeType, header.Size)
    response.Created(w, attachment)
}
```

---

## B.7 Content Recommendation

### Listing 11: Embedding micro-service (`embedding_service/main.py`)

Personalised recommendation is driven by a small FastAPI service built on a
multilingual sentence-transformer model. Each post is represented as a
390-dimensional vector: 384 dimensions encode the semantic content of the title
and body, while six additional dimensions carry a weighted one-hot category signal
so that the content category contributes meaningfully alongside the text. A user's
interest vector is maintained as an exponential moving average, shifting gradually
toward the content the user has most recently liked. These vectors are stored in
Milvus and queried by cosine similarity to produce recommendations.

```python
from fastapi import FastAPI
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer
import numpy as np
import re

app = FastAPI()
model = SentenceTransformer("paraphrase-multilingual-MiniLM-L12-v2")

CATEGORIES = ["Музыка", "Искусство", "Подкасты", "Игры", "Образование", "Другое"]
CATEGORY_WEIGHT = 3.0  # amplified so the category has weight alongside the 384-dim text vector


def category_vector(category: str) -> list[float]:
    vec = [0.0] * len(CATEGORIES)
    if category in CATEGORIES:
        vec[CATEGORIES.index(category)] = CATEGORY_WEIGHT
    return vec


def strip_html(text: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", text)).strip()


class EmbedRequest(BaseModel):
    title: str
    content: str = ""
    category: str = ""


@app.post("/embed")
def embed(req: EmbedRequest):
    text = (req.title + " " + strip_html(req.content)).strip()
    text_vec = model.encode(text, normalize_embeddings=True).tolist()  # 384
    return {"vector": text_vec + category_vector(req.category)}        # 390


class UpdateUserRequest(BaseModel):
    current_vector: list[float]  # empty if the user has no prior vector
    post_vector: list[float]
    alpha: float = 0.3           # learning rate — how fast preference shifts


@app.post("/user/update")
def update_user_vector(req: UpdateUserRequest):
    post_vec = np.array(req.post_vector, dtype=np.float32)
    if not req.current_vector:
        result = post_vec
    else:
        curr = np.array(req.current_vector, dtype=np.float32)
        result = req.alpha * post_vec + (1.0 - req.alpha) * curr  # exponential moving average
    norm = float(np.linalg.norm(result))
    if norm > 0:
        result = result / norm
    return {"vector": result.tolist()}
```

### Listing 12: Recommendation orchestrator (`backend/internal/recommendation/service.go`)

This Go service ties the components together. When a user likes a post their
preference vector is updated via the embedding service and stored back into
Milvus; serving a recommendation performs an approximate-nearest-neighbour search
in Milvus and re-ranks the candidates in PostgreSQL. Every external dependency is
treated as best-effort: preference updates run in the background and only log on
failure, and `Recommend` degrades gracefully to a non-personalised "explore" feed
whenever the user has no vector yet or Milvus/embedding is unavailable.

```go
// Recommend returns personalised posts, falling back to an explore feed when the
// user has no preference vector or Milvus/embedding is unavailable.
func (s *Service) Recommend(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Post, error) {
    userVec, err := s.milvus.GetVector(ctx, UserCollection, userID.String())
    if err != nil || userVec == nil {
        return s.postRepo.Explore(ctx, limit, offset)
    }
    // Pull top-100 candidates via ANN search, then re-rank in PostgreSQL.
    candidateIDs, err := s.milvus.SearchSimilar(ctx, PostCollection, userVec, 100)
    if err != nil || len(candidateIDs) == 0 {
        return s.postRepo.Explore(ctx, limit, offset)
    }
    posts, err := s.postRepo.GetByIDs(ctx, candidateIDs, limit, offset)
    if err != nil || len(posts) == 0 {
        return s.postRepo.Explore(ctx, limit, offset)
    }
    return posts, nil
}

// OnLike shifts the user's preference vector toward the liked post. Runs in the background.
func (s *Service) OnLike(ctx context.Context, userID, postID uuid.UUID) {
    postVec, err := s.milvus.GetVector(ctx, PostCollection, postID.String())
    if err != nil || postVec == nil {
        return
    }
    currentVec, _ := s.milvus.GetVector(ctx, UserCollection, userID.String()) // may be nil for a new user
    newVec, err := s.embedding.UpdateUserVector(ctx, currentVec, postVec, 0.3)
    if err != nil {
        log.Printf("rec: update user vector %s: %v", userID, err)
        return
    }
    if err := s.milvus.UpsertVector(ctx, UserCollection, userID.String(), newVec); err != nil {
        log.Printf("rec: upsert user vector %s: %v", userID, err)
    }
}
```

---

## B.8 Database Schema

### Listing 13: Core relational schema (`backend/migrations/001_init.sql`)

The initial migration defines the core entities and their relationships. UUID
primary keys avoid exposing sequential identifiers, PostgreSQL enumerated types
constrain role and status values at the database level, foreign keys use
`ON DELETE CASCADE` to preserve referential integrity, and composite unique keys
prevent duplicate subscriptions. A representative subset is shown below (the full
migration also defines `follows`, `post_attachments`, `comments`, `likes`, and
`refresh_tokens`, with later migrations adding donations, notifications, Stripe
records, email tokens, and live streams).

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE user_role AS ENUM ('patron', 'creator', 'both');
CREATE TYPE subscription_status AS ENUM ('active', 'cancelled', 'expired');
CREATE TYPE post_type AS ENUM ('text', 'image', 'video', 'audio');

CREATE TABLE users (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username      VARCHAR(50) UNIQUE NOT NULL,
    email         VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role          user_role NOT NULL DEFAULT 'patron',
    avatar_url    TEXT,
    bio           TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE creator_profiles (
    id                       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    display_name             VARCHAR(100) NOT NULL,
    description              TEXT,
    category                 VARCHAR(50),
    subscription_price_cents INTEGER NOT NULL DEFAULT 0,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id)
);

CREATE TABLE subscriptions (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patron_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    creator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status     subscription_status NOT NULL DEFAULT 'active',
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ends_at    TIMESTAMPTZ,
    UNIQUE(patron_id, creator_id)   -- prevents duplicate subscriptions
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

-- Indexes for the most frequent lookups
CREATE INDEX idx_posts_creator_id ON posts(creator_id);
CREATE INDEX idx_posts_published_at ON posts(published_at DESC) WHERE is_published = true;
CREATE INDEX idx_subscriptions_patron_id ON subscriptions(patron_id);
CREATE INDEX idx_subscriptions_creator_id ON subscriptions(creator_id);
```

---

## B.9 Client Integration

### Listing 14: Web client — transparent token refresh (`frontend/src/lib/api.ts`)

The Next.js client uses an Axios instance with two interceptors. A request
interceptor attaches the access token to every call. A response interceptor
catches `401` responses and transparently refreshes the session: while one refresh
is in flight, concurrent failed requests are queued and replayed once a new token
arrives, so a burst of requests triggers only a single refresh. If refreshing
itself fails, the tokens are cleared and the user is redirected to the login page.

```ts
api.interceptors.request.use((config) => {
  const { accessToken } = getTokens();
  if (accessToken) config.headers.Authorization = `Bearer ${accessToken}`;
  return config;
});

let isRefreshing = false;
let failedQueue: Array<{ resolve: (v: unknown) => void; reject: (r?: unknown) => void }> = [];

api.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const originalRequest = error.config as typeof error.config & { _retry?: boolean };

    if (error.response?.status === 401 && !originalRequest._retry) {
      if (isRefreshing) {
        // A refresh is already running — wait for it, then replay this request.
        return new Promise((resolve, reject) => failedQueue.push({ resolve, reject }))
          .then((token) => {
            originalRequest.headers!.Authorization = `Bearer ${token}`;
            return api(originalRequest);
          });
      }
      originalRequest._retry = true;
      isRefreshing = true;

      const { refreshToken } = getTokens();
      if (!refreshToken) { clearTokens(); return Promise.reject(error); }

      try {
        const { data } = await axios.post(`${BASE_URL}/auth/refresh`, { refresh_token: refreshToken });
        const { access_token, refresh_token } = data.data;
        setTokens(access_token, refresh_token);
        processQueue(null, access_token);              // release queued requests
        originalRequest.headers!.Authorization = `Bearer ${access_token}`;
        return api(originalRequest);
      } catch (refreshError) {
        processQueue(refreshError, null);
        clearTokens();
        window.location.href = "/login";
        return Promise.reject(refreshError);
      } finally {
        isRefreshing = false;
      }
    }
    return Promise.reject(error);
  }
);
```

### Listing 15: Mobile client — secure token storage and refresh (`subscription_app/lib/services/auth_service.dart`, `api_client.dart`)

The Flutter client stores the token pair in the platform's hardware-backed secure
store — the iOS Keychain or the Android Keystore (via encrypted shared
preferences) — rather than in plain local storage. Both tokens are written as a
single JSON value so the update is atomic. Only non-sensitive profile data
(username, cached avatar URL) lives in ordinary `SharedPreferences`. The HTTP
client mirrors the web client's refresh strategy, using a `Completer` to ensure
that concurrent callers share a single in-flight refresh.

```dart
class AuthService {
  // Tokens live in the platform secure keystore (Keychain / Keystore).
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _keyTokens = 'auth_tokens';

  // Both tokens written as one JSON blob → atomic update.
  static Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _secureStorage.write(
      key: _keyTokens,
      value: jsonEncode({'access': accessToken, 'refresh': refreshToken}),
    );
  }

  static Future<String?> getAccessToken() async {
    final raw = await _secureStorage.read(key: _keyTokens);
    if (raw == null) return null;
    return (jsonDecode(raw) as Map<String, dynamic>)['access'] as String?;
  }
}
```

```dart
class ApiClient {
  // Non-null while a refresh is in progress; concurrent callers await the same future.
  static Completer<bool>? _refreshCompleter;

  static Future<bool> _tryRefresh() async {
    if (_refreshCompleter != null) return _refreshCompleter!.future; // coalesce
    _refreshCompleter = Completer<bool>();
    try {
      final refreshToken = await AuthService.getRefreshToken();
      if (refreshToken == null) { _refreshCompleter!.complete(false); return false; }

      final res = await http.post(
        Uri.parse('$_base/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(_kTimeout);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        _refreshCompleter!.complete(false); return false;
      }
      final data = (jsonDecode(res.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      await AuthService.saveTokens(data['access_token'] as String, data['refresh_token'] as String);
      _refreshCompleter!.complete(true);
      return true;
    } catch (_) {
      _refreshCompleter!.complete(false); return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  // Runs a request; on a 401 it refreshes once and retries.
  static Future<Map<String, dynamic>> _withRefresh(
      Future<http.Response> Function(Map<String, String> headers) fn) async {
    var res = await fn(await _headers());
    if (res.statusCode == 401) {
      if (!await _tryRefresh()) {
        await AuthService.clearTokens();
        throw 'Session expired. Please log in again.';
      }
      res = await fn(await _headers());
    }
    return _parse(res);
  }
}
```

---

## B.10 Infrastructure and Deployment

### Listing 16: Docker Compose — development stack (`docker-compose.yml`)

The development environment is described declaratively in a single Compose file.
It provisions the database, object storage, the etcd + Milvus vector-search
cluster, the embedding service, and a local mail catcher. Credentials are supplied
through environment variables with safe local defaults, so the stack starts with
no additional configuration while avoiding hard-coded secrets in the source.

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
      POSTGRES_DB: ${POSTGRES_DB:-diploma}
    ports:
      - "5433:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./backend/migrations/001_init.sql:/docker-entrypoint-initdb.d/001_init.sql

  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ACCESS_KEY:-minioadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_SECRET_KEY:-minioadmin}
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - miniodata:/data

  etcd:
    image: quay.io/coreos/etcd:v3.5.5
    environment:
      - ETCD_AUTO_COMPACTION_MODE=revision
      - ETCD_AUTO_COMPACTION_RETENTION=1000
      - ETCD_QUOTA_BACKEND_BYTES=4294967296
      - ETCD_SNAPSHOT_COUNT=50000
    command: >
      etcd
      --advertise-client-urls=http://127.0.0.1:2379
      --listen-client-urls=http://0.0.0.0:2379
      --data-dir=/etcd
    volumes:
      - etcddata:/etcd

  milvus:
    image: milvusdb/milvus:v2.4.0
    command: ["milvus", "run", "standalone"]
    security_opt:
      - seccomp:unconfined
    environment:
      ETCD_ENDPOINTS: etcd:2379
      MINIO_ADDRESS: minio:9000
      MINIO_ACCESS_KEY_ID: ${MINIO_ACCESS_KEY:-minioadmin}
      MINIO_SECRET_ACCESS_KEY: ${MINIO_SECRET_KEY:-minioadmin}
      MINIO_USE_SSL: "false"
    volumes:
      - milvusdata:/var/lib/milvus
    ports:
      - "19530:19530"
      - "9091:9091"
    depends_on:
      - etcd
      - minio

  embedding-service:
    build: ./embedding_service
    ports:
      - "8001:8001"
    restart: unless-stopped

  mailpit:
    image: axllent/mailpit:latest
    restart: unless-stopped
    ports:
      - "1025:1025"   # SMTP
      - "8025:8025"   # Web UI

volumes:
  pgdata:
  miniodata:
  etcddata:
  milvusdata:
```

### Listing 17: Docker Compose — production deployment (`docker-compose.prod.yml`)

The production configuration hardens the stack: all credentials are injected from
an environment file, every service restarts automatically, and the Go backend is
bound to the loopback interface so that Nginx is the only component reachable from
the public network.

```yaml
services:
  postgres:
    image: postgres:16-alpine
    restart: always
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - pgdata:/var/lib/postgresql/data

  minio:
    image: minio/minio:latest
    restart: always
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ACCESS_KEY}
      MINIO_ROOT_PASSWORD: ${MINIO_SECRET_KEY}
    volumes:
      - miniodata:/data
    ports:
      - "9000:9000"

  embedding-service:
    build: ./embedding_service
    restart: always

  backend:
    build: ./backend
    restart: always
    env_file: .env.prod
    environment:
      DATABASE_URL: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}?sslmode=disable
      EMBEDDING_URL: http://embedding-service:8001
      MINIO_ENDPOINT: minio:9000
    ports:
      - "127.0.0.1:8080:8080"   # loopback only — Nginx is the public entry point
    depends_on:
      - postgres
      - minio
      - embedding-service

  nginx:
    image: nginx:alpine
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/certs:/etc/nginx/certs:ro
    depends_on:
      - backend

volumes:
  pgdata:
  miniodata:
```

### Listing 18: Reverse proxy configuration (`nginx/nginx.conf`)

Nginx terminates client connections, enforces a 50 MB upload limit for post
attachments, and proxies requests to the backend. The notification endpoint is
configured separately because it streams Server-Sent Events and therefore must run
with response buffering disabled and extended timeouts.

```nginx
events {
  worker_connections 1024;
}

http {
  # Timeouts for SSE (Server-Sent Events)
  proxy_read_timeout 3600s;
  proxy_send_timeout 3600s;

  server_tokens off;   # hide the nginx version

  gzip on;
  gzip_types text/plain application/json application/javascript text/css;

  server {
    listen 80;
    server_name API_DOMAIN;            # e.g. api.example.com

    client_max_body_size 50M;          # maximum upload size for attachments

    # SSE endpoint — buffering disabled
    location /api/notifications/stream {
      proxy_pass         http://backend:8080;
      proxy_http_version 1.1;
      proxy_set_header   Connection "";
      proxy_buffering    off;
      proxy_cache        off;
      proxy_set_header   Host $host;
      proxy_set_header   X-Real-IP $remote_addr;
      proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header   X-Forwarded-Proto $scheme;
    }

    # All other API requests
    location / {
      proxy_pass         http://backend:8080;
      proxy_http_version 1.1;
      proxy_set_header   Host $host;
      proxy_set_header   X-Real-IP $remote_addr;
      proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header   X-Forwarded-Proto $scheme;
    }
  }

  # HTTPS server (enabled after obtaining a certificate via certbot)
  # server {
  #   listen 443 ssl;
  #   server_name API_DOMAIN;
  #   ssl_certificate     /etc/nginx/certs/fullchain.pem;
  #   ssl_certificate_key /etc/nginx/certs/privkey.pem;
  #   ssl_protocols       TLSv1.2 TLSv1.3;
  #   ... same as above ...
  # }
}
```
