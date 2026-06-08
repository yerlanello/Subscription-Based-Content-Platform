package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"diploma/backend/internal/email"
	"diploma/backend/internal/handlers"
	"diploma/backend/internal/hub"
	"diploma/backend/internal/middleware"
	"diploma/backend/internal/recommendation"
	"diploma/backend/internal/repository"
	"diploma/backend/internal/service"
	"diploma/backend/internal/storage"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/joho/godotenv"
)

func main() {
	// .env is optional — in production env vars are injected by the container
	if err := godotenv.Load(); err != nil {
		log.Printf("info: no .env file found, using environment variables")
	}

	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		log.Fatal("DATABASE_URL is required")
	}
	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		log.Fatal("JWT_SECRET is required")
	}
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
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

	// Storage (MinIO) — optional, degrades gracefully
	var minioStorage *storage.MinioStorage
	if minioEndpoint := os.Getenv("MINIO_ENDPOINT"); minioEndpoint != "" {
		bucket := os.Getenv("MINIO_BUCKET")
		if bucket == "" {
			bucket = "media"
		}
		minioStorage, err = storage.NewMinioStorage(
			minioEndpoint,
			os.Getenv("MINIO_ACCESS_KEY"),
			os.Getenv("MINIO_SECRET_KEY"),
			bucket,
			os.Getenv("MINIO_PUBLIC_URL"),
		)
		if err != nil {
			log.Printf("warn: minio init failed: %v", err)
		}
	}

	// Repos
	userRepo := repository.NewUserRepo(pool)
	creatorRepo := repository.NewCreatorRepo(pool)
	postRepo := repository.NewPostRepo(pool)
	commentRepo := repository.NewCommentRepo(pool)
	subRepo := repository.NewSubscriptionRepo(pool)
	followRepo := repository.NewFollowRepo(pool)
	notifRepo := repository.NewNotificationRepo(pool)
	donationRepo := repository.NewDonationRepo(pool)
	tokenRepo := repository.NewTokenRepo(pool)
	sRepo := repository.NewStreamRepo(pool)

	notifHub := hub.New()

	emailSvc := email.NewService(
		os.Getenv("SMTP_HOST"), os.Getenv("SMTP_PORT"),
		os.Getenv("SMTP_USER"), os.Getenv("SMTP_PASS"),
		os.Getenv("SMTP_FROM"), os.Getenv("APP_URL"),
	)

	authSvc := service.NewAuthService(userRepo, jwtSecret, emailSvc, tokenRepo)
	postSvc := service.NewPostService(postRepo, subRepo, notifRepo, userRepo, commentRepo, notifHub)

	// Recommendation system — optional, only enabled if MILVUS_ADDR is explicitly set
	var recSvc *recommendation.Service
	if milvusAddr := os.Getenv("MILVUS_ADDR"); milvusAddr != "" {
		embeddingURL := os.Getenv("EMBEDDING_URL")
		if embeddingURL == "" {
			embeddingURL = "http://localhost:8001"
		}
		milvusClient, err := recommendation.NewMilvusClient(ctx, milvusAddr, os.Getenv("MILVUS_API_KEY"))
		if err != nil {
			log.Printf("warn: milvus unavailable, recommendations disabled: %v", err)
		} else {
			embClient := recommendation.NewEmbeddingClient(embeddingURL)
			recSvc = recommendation.NewService(milvusClient, embClient, postRepo, creatorRepo)
			log.Printf("recommendation system ready")
			defer milvusClient.Close()
		}
	} else {
		log.Printf("info: recommendations disabled (MILVUS_ADDR not set)")
	}

	// Handlers
	authH := handlers.NewAuthHandler(authSvc)
	userH := handlers.NewUserHandler(userRepo, minioStorage)
	creatorH := handlers.NewCreatorHandler(creatorRepo, userRepo, subRepo, followRepo, notifRepo, notifHub, minioStorage)
	postH := handlers.NewPostHandler(postSvc, commentRepo, userRepo, postRepo, notifRepo, notifHub, minioStorage, recSvc)
	notifH := handlers.NewNotificationHandler(notifRepo, notifHub)
	stripeH := handlers.NewStripeHandler(subRepo, creatorRepo, userRepo, donationRepo, notifRepo, notifHub)
	billingH := handlers.NewBillingHandler(subRepo, donationRepo)
	streamH := handlers.NewStreamHandler(sRepo, notifRepo, notifHub)

	// Rate limiters
	// General API: 60 req/s per IP, burst 120
	generalRL := middleware.NewRateLimiter(60, 120)
	// Auth endpoints: 5 attempts per minute per IP (1 token per 12s, burst 5)
	// After 5 quick attempts, must wait 12s between each next attempt
	authRL := middleware.NewRateLimiter(1.0/12, 5)

	// Router
	r := chi.NewRouter()
	r.Use(chimiddleware.Logger)
	r.Use(chimiddleware.Recoverer)
	r.Use(chimiddleware.RequestID)
	r.Use(chimiddleware.RealIP)
	r.Use(generalRL.Handler)

	allowedOrigins := []string{"http://localhost:3000", "http://localhost:3001"}
	if frontendURL := os.Getenv("FRONTEND_URL"); frontendURL != "" {
		allowedOrigins = append(allowedOrigins, frontendURL)
		// also allow www. variant
		if len(frontendURL) > 8 && frontendURL[:8] == "https://" {
			allowedOrigins = append(allowedOrigins, "https://www."+frontendURL[8:])
		}
	}
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   allowedOrigins,
		AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Authorization", "Content-Type"},
		AllowCredentials: true,
	}))

	authMiddleware := middleware.Auth(jwtSecret)
	optionalAuth := middleware.OptionalAuth(jwtSecret)

	r.Route("/api", func(r chi.Router) {
		// Auth — stricter rate limit
		r.Route("/auth", func(r chi.Router) {
			r.Use(authRL.Handler)
			r.Post("/register", authH.Register)
			r.Post("/login", authH.Login)
			r.Post("/refresh", authH.Refresh)
			r.With(authMiddleware).Delete("/logout", authH.Logout)
			r.With(authMiddleware).Delete("/logout-all", authH.LogoutAll)
			r.Post("/verify-email", authH.VerifyEmail)
			r.With(authMiddleware).Post("/resend-verification", authH.ResendVerification)
			r.With(authMiddleware).Put("/change-password", authH.ChangePassword)
			r.Post("/forgot-password", authH.ForgotPassword)
			r.Post("/reset-password", authH.ResetPassword)
		})

		// Users
		r.Route("/users", func(r chi.Router) {
			r.With(authMiddleware).Get("/me", userH.Me)
			r.With(authMiddleware).Put("/me", userH.UpdateMe)
			r.With(authMiddleware).Post("/me/avatar", userH.UploadAvatar)
			r.With(authMiddleware).Get("/me/subscriptions", creatorH.MySubscriptions)
			r.With(authMiddleware).Get("/me/following", creatorH.MyFollowing)
			r.With(authMiddleware).Get("/me/billing", billingH.History)
			r.Get("/{username}", userH.GetByUsername)
		})

		// Creators
		r.Route("/creators", func(r chi.Router) {
			r.With(optionalAuth).Get("/", creatorH.List)
			r.With(authMiddleware).Post("/", creatorH.BecomeCreator)
			r.With(optionalAuth).Get("/{username}", creatorH.GetCreatorByUsername)
			r.With(authMiddleware).Put("/{username}", creatorH.UpdateProfile)
			r.With(authMiddleware).Post("/{username}/subscribe", creatorH.Subscribe)
			r.With(authMiddleware).Delete("/{username}/subscribe", creatorH.Unsubscribe)
			r.With(authMiddleware).Post("/{username}/follow", creatorH.Follow)
			r.With(authMiddleware).Delete("/{username}/follow", creatorH.Unfollow)
			r.With(optionalAuth).Get("/{username}/posts", postH.ListByCreator)
			r.With(authMiddleware).Post("/{username}/checkout", stripeH.CreateCheckout)
			r.With(authMiddleware).Post("/{username}/checkout-intent", stripeH.CreateSubscriptionIntent)
			r.With(authMiddleware).Post("/{username}/donate-intent", stripeH.CreateDonationIntent)
			r.With(authMiddleware).Post("/{username}/cover", creatorH.UploadCover)
		})

		r.Post("/webhooks/stripe", stripeH.Webhook)
		r.With(authMiddleware).Post("/subscriptions/verify-session", stripeH.VerifySession)
		r.With(authMiddleware).Post("/creators/{username}/donate", stripeH.CreateDonationCheckout)
		r.With(authMiddleware).Post("/donations/verify", stripeH.VerifyDonation)

		// Notifications
		sseAuth := middleware.SSEAuth(jwtSecret)
		r.Route("/notifications", func(r chi.Router) {
			r.With(authMiddleware).Get("/", notifH.List)
			r.With(sseAuth).Get("/stream", notifH.Stream)
			r.With(authMiddleware).Post("/read-all", notifH.MarkAllRead)
			r.With(authMiddleware).Delete("/", notifH.DeleteAll)
			r.With(authMiddleware).Post("/{id}/read", notifH.MarkRead)
			r.With(authMiddleware).Delete("/{id}", notifH.Delete)
		})

		// Posts
		r.Route("/posts", func(r chi.Router) {
			r.With(authMiddleware).Get("/feed", postH.Feed)
			r.With(optionalAuth).Get("/explore", postH.Explore)
			r.With(authMiddleware).Get("/recommended", postH.Recommended)
			r.With(authMiddleware).Post("/", postH.Create)
			r.With(optionalAuth).Get("/{id}", postH.Get)
			r.With(authMiddleware).Put("/{id}", postH.Update)
			r.With(authMiddleware).Post("/{id}/publish", postH.Publish)
			r.With(authMiddleware).Post("/{id}/unpublish", postH.Unpublish)
			r.With(authMiddleware).Delete("/{id}", postH.Delete)
			r.With(authMiddleware).Post("/{id}/like", postH.Like)
			r.With(authMiddleware).Delete("/{id}/like", postH.Unlike)
			r.With(optionalAuth).Get("/{id}/comments", postH.GetComments)
			r.With(authMiddleware).Post("/{id}/comments", postH.CreateComment)
			r.With(authMiddleware).Delete("/{id}/comments/{commentId}", postH.DeleteComment)
			r.With(authMiddleware).Post("/{id}/comments/{commentId}/like", postH.LikeComment)
			r.With(authMiddleware).Delete("/{id}/comments/{commentId}/like", postH.UnlikeComment)
			r.With(authMiddleware).Post("/{id}/attachments", postH.UploadAttachment)
			r.With(authMiddleware).Post("/{id}/attachments/url", postH.AddAttachmentURL)
			r.With(authMiddleware).Delete("/{id}/attachments/{attachmentId}", postH.DeleteAttachment)
			r.With(authMiddleware).Post("/{id}/pin", postH.PinPost)
			r.With(authMiddleware).Delete("/{id}/pin", postH.UnpinPost)
		})

		// Streams
		r.Route("/streams", func(r chi.Router) {
			r.Get("/", streamH.List)
			r.With(authMiddleware).Get("/my", streamH.GetMine)
			r.With(authMiddleware).Post("/start", streamH.Start)
			r.Get("/by-creator/{username}", streamH.GetByCreator)
			r.Get("/{id}", streamH.Get)
			r.Get("/{id}/messages", streamH.GetMessages)
			r.With(authMiddleware).Post("/{id}/end", streamH.End)
			r.With(authMiddleware).Post("/{id}/join", streamH.Join)
			r.With(authMiddleware).Patch("/{id}/location", streamH.UpdateLocation)
			r.With(authMiddleware).Post("/{id}/messages", streamH.SendMessage)
		})
	})

	// Clean up stale streams on startup, then every 10 minutes
	if err := sRepo.EndStale(ctx); err != nil {
		log.Printf("warn: stale stream cleanup failed: %v", err)
	}
	go func() {
		for range time.Tick(10 * time.Minute) {
			if err := sRepo.EndStale(context.Background()); err != nil {
				log.Printf("warn: stale stream cleanup failed: %v", err)
			}
		}
	}()

	log.Printf("server starting on :%s", port)
	if err := http.ListenAndServe(fmt.Sprintf(":%s", port), r); err != nil {
		log.Fatal(err)
	}
}
