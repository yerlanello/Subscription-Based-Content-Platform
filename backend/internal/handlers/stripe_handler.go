package handlers

import (
	"encoding/json"
	"io"
	"log"
	"net/http"
	"os"

	"diploma/backend/internal/middleware"
	"diploma/backend/internal/repository"
	"diploma/backend/internal/response"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	stripe "github.com/stripe/stripe-go/v79"
	"github.com/stripe/stripe-go/v79/checkout/session"
	"github.com/stripe/stripe-go/v79/webhook"
)

type StripeHandler struct {
	subRepo     *repository.SubscriptionRepo
	creatorRepo *repository.CreatorRepo
	userRepo    *repository.UserRepo
}

func NewStripeHandler(subRepo *repository.SubscriptionRepo, creatorRepo *repository.CreatorRepo, userRepo *repository.UserRepo) *StripeHandler {
	stripe.Key = os.Getenv("STRIPE_SECRET_KEY")
	return &StripeHandler{subRepo: subRepo, creatorRepo: creatorRepo, userRepo: userRepo}
}

// CreateCheckout — POST /api/creators/{username}/checkout
// Создаёт Stripe Checkout Session и возвращает URL для редиректа
func (h *StripeHandler) CreateCheckout(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	if claims == nil {
		response.Error(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	username := chi.URLParam(r, "username")

	// Получаем пользователя-автора
	creatorUser, err := h.userRepo.GetByUsername(r.Context(), username)
	if err != nil {
		response.Error(w, http.StatusNotFound, "creator not found")
		return
	}

	// Получаем профиль автора
	profile, err := h.creatorRepo.GetByUserID(r.Context(), creatorUser.ID)
	if err != nil {
		response.Error(w, http.StatusNotFound, "creator profile not found")
		return
	}

	frontendURL := os.Getenv("FRONTEND_URL")
	if frontendURL == "" {
		frontendURL = "http://localhost:3000"
	}

	// KZT — не zero-decimal валюта, передаём в тиынах (x100)
	amountTiyn := int64(profile.SubscriptionPriceCents) * 100

	params := &stripe.CheckoutSessionParams{
		Mode: stripe.String(string(stripe.CheckoutSessionModePayment)),
		LineItems: []*stripe.CheckoutSessionLineItemParams{
			{
				PriceData: &stripe.CheckoutSessionLineItemPriceDataParams{
					Currency:   stripe.String("kzt"),
					UnitAmount: stripe.Int64(amountTiyn),
					ProductData: &stripe.CheckoutSessionLineItemPriceDataProductDataParams{
						Name: stripe.String("Подписка на " + profile.DisplayName),
					},
				},
				Quantity: stripe.Int64(1),
			},
		},
		SuccessURL: stripe.String(frontendURL + "/subscribe/success?creator=" + username + "&session_id={CHECKOUT_SESSION_ID}"),
		CancelURL:  stripe.String(frontendURL + "/" + username),
		Metadata: map[string]string{
			"patron_id":  claims.UserID.String(),
			"creator_id": creatorUser.ID.String(),
		},
	}

	sess, err := session.New(params)
	if err != nil {
		log.Printf("stripe checkout error: %v", err)
		response.Error(w, http.StatusInternalServerError, "failed to create checkout session")
		return
	}

	response.OK(w, map[string]string{"url": sess.URL})
}

// VerifySession — POST /api/subscriptions/verify-session
// Вызывается со страницы успеха: проверяет Stripe-сессию и создаёт подписку.
// Не требует webhook secret — мы сами идём в Stripe API.
func (h *StripeHandler) VerifySession(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	if claims == nil {
		response.Error(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var body struct {
		SessionID string `json:"session_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.SessionID == "" {
		response.Error(w, http.StatusBadRequest, "session_id required")
		return
	}

	sess, err := session.Get(body.SessionID, nil)
	if err != nil {
		log.Printf("stripe: cannot get session %s: %v", body.SessionID, err)
		response.Error(w, http.StatusBadRequest, "invalid session")
		return
	}

	if sess.PaymentStatus != stripe.CheckoutSessionPaymentStatusPaid {
		response.Error(w, http.StatusPaymentRequired, "payment not completed")
		return
	}

	patronID, err1 := uuid.Parse(sess.Metadata["patron_id"])
	creatorID, err2 := uuid.Parse(sess.Metadata["creator_id"])
	if err1 != nil || err2 != nil {
		response.Error(w, http.StatusBadRequest, "invalid session metadata")
		return
	}

	// Убеждаемся что это тот же пользователь
	if patronID != claims.UserID {
		response.Error(w, http.StatusForbidden, "forbidden")
		return
	}

	if _, err := h.subRepo.Subscribe(r.Context(), patronID, creatorID); err != nil {
		log.Printf("stripe: failed to create subscription: %v", err)
		response.Error(w, http.StatusInternalServerError, "failed to create subscription")
		return
	}

	response.OK(w, map[string]string{"status": "subscribed"})
}

// Webhook — POST /api/webhooks/stripe
// Обрабатывает события от Stripe (checkout.session.completed → создаём подписку)
func (h *StripeHandler) Webhook(w http.ResponseWriter, r *http.Request) {
	payload, err := io.ReadAll(r.Body)
	if err != nil {
		response.Error(w, http.StatusBadRequest, "cannot read body")
		return
	}

	endpointSecret := os.Getenv("STRIPE_WEBHOOK_SECRET")
	sig := r.Header.Get("Stripe-Signature")

	var event stripe.Event

	if endpointSecret != "" {
		event, err = webhook.ConstructEvent(payload, sig, endpointSecret)
		if err != nil {
			log.Printf("stripe webhook signature error: %v", err)
			response.Error(w, http.StatusBadRequest, "invalid signature")
			return
		}
	} else {
		// В dev-режиме без секрета — парсим напрямую
		if err := json.Unmarshal(payload, &event); err != nil {
			response.Error(w, http.StatusBadRequest, "cannot parse event")
			return
		}
	}

	switch event.Type {
	case "checkout.session.completed":
		var sess stripe.CheckoutSession
		if err := json.Unmarshal(event.Data.Raw, &sess); err != nil {
			log.Printf("stripe: cannot parse checkout session: %v", err)
			w.WriteHeader(http.StatusOK)
			return
		}

		patronID, err1 := uuid.Parse(sess.Metadata["patron_id"])
		creatorID, err2 := uuid.Parse(sess.Metadata["creator_id"])
		if err1 != nil || err2 != nil {
			log.Printf("stripe: invalid metadata patron=%s creator=%s", sess.Metadata["patron_id"], sess.Metadata["creator_id"])
			w.WriteHeader(http.StatusOK)
			return
		}

		if _, err := h.subRepo.Subscribe(r.Context(), patronID, creatorID); err != nil {
			log.Printf("stripe: failed to create subscription: %v", err)
		} else {
			log.Printf("stripe: subscription created patron=%s creator=%s", patronID, creatorID)
		}
	}

	w.WriteHeader(http.StatusOK)
}
