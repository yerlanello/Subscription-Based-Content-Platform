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
	_ = godotenv.Load()

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

	// Run migrations
	if err := repository.RunMigrations(ctx, pool); err != nil {
		log.Fatalf("migrations: %v", err)
	}

	// Storage (MinIO)
	minioEndpoint := os.Getenv("MINIO_ENDPOINT")
	minioAccess := os.Getenv("MINIO_ACCESS_KEY")
	minioSecret := os.Getenv("MINIO_SECRET_KEY")
	minioBucket := os.Getenv("MINIO_BUCKET")
	minioPublicURL := os.Getenv("MINIO_PUBLIC_URL")
	if minioBucket == "" {
		minioBucket = "media"
	}
	var minioStorage *storage.MinioStorage
	if minioEndpoint != "" {
		var err error
		minioStorage, err = storage.NewMinioStorage(minioEndpoint, minioAccess, minioSecret, minioBucket, minioPublicURL)
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

	// Hub
	notifHub := hub.New()

	// Email service
	emailSvc := email.NewService(
		os.Getenv("SMTP_HOST"), os.Getenv("SMTP_PORT"),
		os.Getenv("SMTP_USER"), os.Getenv("SMTP_PASS"),
		os.Getenv("SMTP_FROM"), os.Getenv("APP_URL"),
	)

	// Services
	authSvc := service.NewAuthService(userRepo, jwtSecret, emailSvc, tokenRepo)
	postSvc := service.NewPostService(postRepo, subRepo, notifRepo, userRepo, commentRepo, notifHub)

	// Recommendation system (optional — degrades gracefully if unavailable)
	var recSvc *recommendation.Service
	milvusAddr := os.Getenv("MILVUS_ADDR")
	embeddingURL := os.Getenv("EMBEDDING_URL")
	if milvusAddr == "" {
		milvusAddr = "localhost:19530"
	}
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

	// Handlers
	authH := handlers.NewAuthHandler(authSvc)
	userH := handlers.NewUserHandler(userRepo, minioStorage)
	creatorH := handlers.NewCreatorHandler(creatorRepo, userRepo, subRepo, followRepo, minioStorage)
	postH := handlers.NewPostHandler(postSvc, commentRepo, userRepo, postRepo, minioStorage, recSvc)
	notifH := handlers.NewNotificationHandler(notifRepo, notifHub)
	stripeH := handlers.NewStripeHandler(subRepo, creatorRepo, userRepo, donationRepo)
	billingH := handlers.NewBillingHandler(subRepo, donationRepo)
	sRepo := repository.NewStreamRepo(pool)
	streamH := handlers.NewStreamHandler(sRepo, notifRepo, notifHub)

	// Router
	r := chi.NewRouter()
	r.Use(chimiddleware.Logger)
	r.Use(chimiddleware.Recoverer)
	r.Use(chimiddleware.RequestID)
	allowedOrigins := []string{"http://localhost:3000", "http://localhost:3001"}
	if frontendURL := os.Getenv("FRONTEND_URL"); frontendURL != "" {
		allowedOrigins = append(allowedOrigins, frontendURL)
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
		// Auth
		r.Route("/auth", func(r chi.Router) {
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
			r.With(authMiddleware).Post("/{username}/cover", creatorH.UploadCover)
		})

		// Stripe webhook (no auth — Stripe подписывает запрос своей подписью)
		r.Post("/webhooks/stripe", stripeH.Webhook)
		// Verify stripe session and create subscription
		r.With(authMiddleware).Post("/subscriptions/verify-session", stripeH.VerifySession)
		// Donations
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
	sRepo.EndStale(ctx)
	go func() {
		for {
			time.Sleep(10 * time.Minute)
			sRepo.EndStale(context.Background())
		}
	}()

	log.Printf("server starting on :%s", port)
	if err := http.ListenAndServe(fmt.Sprintf(":%s", port), r); err != nil {
		log.Fatal(err)
	}
}
