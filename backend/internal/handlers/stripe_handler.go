package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"

	"diploma/backend/internal/hub"
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
	subRepo      *repository.SubscriptionRepo
	creatorRepo  *repository.CreatorRepo
	userRepo     *repository.UserRepo
	donationRepo *repository.DonationRepo
	notifRepo    *repository.NotificationRepo
	notifHub     *hub.Hub
}

func NewStripeHandler(subRepo *repository.SubscriptionRepo, creatorRepo *repository.CreatorRepo, userRepo *repository.UserRepo, donationRepo *repository.DonationRepo, notifRepo *repository.NotificationRepo, notifHub *hub.Hub) *StripeHandler {
	stripe.Key = os.Getenv("STRIPE_SECRET_KEY")
	return &StripeHandler{subRepo: subRepo, creatorRepo: creatorRepo, userRepo: userRepo, donationRepo: donationRepo, notifRepo: notifRepo, notifHub: notifHub}
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
	// Stripe max for KZT: 9_999_999 tenge
	if profile.SubscriptionPriceCents > 9_999_999 {
		response.Error(w, http.StatusBadRequest, "subscription price exceeds maximum allowed (9 999 999 ₸)")
		return
	}
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
	go h.notifyNewSubscriber(patronID, creatorID)

	response.OK(w, map[string]string{"status": "subscribed"})
}

// CreateDonationCheckout — POST /api/creators/{username}/donate
func (h *StripeHandler) CreateDonationCheckout(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	if claims == nil {
		response.Error(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	username := chi.URLParam(r, "username")

	var body struct {
		AmountCents int    `json:"amount_cents"`
		Message     string `json:"message"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.AmountCents <= 0 {
		response.Error(w, http.StatusBadRequest, "amount_cents is required and must be positive")
		return
	}

	creatorUser, err := h.userRepo.GetByUsername(r.Context(), username)
	if err != nil {
		response.Error(w, http.StatusNotFound, "creator not found")
		return
	}

	if creatorUser.ID == claims.UserID {
		response.Error(w, http.StatusBadRequest, "cannot donate to yourself")
		return
	}

	profile, err := h.creatorRepo.GetByUserID(r.Context(), creatorUser.ID)
	if err != nil {
		response.Error(w, http.StatusNotFound, "creator profile not found")
		return
	}

	frontendURL := os.Getenv("FRONTEND_URL")
	if frontendURL == "" {
		frontendURL = "http://localhost:3000"
	}

	if body.AmountCents > 9_999_999 {
		response.Error(w, http.StatusBadRequest, "donation amount exceeds maximum allowed (9 999 999 ₸)")
		return
	}
	amountTiyn := int64(body.AmountCents) * 100

	params := &stripe.CheckoutSessionParams{
		Mode: stripe.String(string(stripe.CheckoutSessionModePayment)),
		LineItems: []*stripe.CheckoutSessionLineItemParams{
			{
				PriceData: &stripe.CheckoutSessionLineItemPriceDataParams{
					Currency:   stripe.String("kzt"),
					UnitAmount: stripe.Int64(amountTiyn),
					ProductData: &stripe.CheckoutSessionLineItemPriceDataProductDataParams{
						Name: stripe.String("Донат для " + profile.DisplayName),
					},
				},
				Quantity: stripe.Int64(1),
			},
		},
		SuccessURL: stripe.String(frontendURL + "/" + username + "?donated=1&session_id={CHECKOUT_SESSION_ID}"),
		CancelURL:  stripe.String(frontendURL + "/" + username),
		Metadata: map[string]string{
			"type":       "donation",
			"donor_id":   claims.UserID.String(),
			"creator_id": creatorUser.ID.String(),
			"amount":     strconv.Itoa(body.AmountCents),
			"message":    body.Message,
		},
	}

	sess, err := session.New(params)
	if err != nil {
		log.Printf("stripe donation checkout error: %v", err)
		response.Error(w, http.StatusInternalServerError, "failed to create checkout session")
		return
	}

	response.OK(w, map[string]string{"url": sess.URL})
}

// VerifyDonation — POST /api/donations/verify
func (h *StripeHandler) VerifyDonation(w http.ResponseWriter, r *http.Request) {
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

	exists, err := h.donationRepo.ExistsBySessionID(r.Context(), body.SessionID)
	if err == nil && exists {
		response.OK(w, map[string]string{"status": "ok"})
		return
	}

	sess, err := session.Get(body.SessionID, nil)
	if err != nil {
		response.Error(w, http.StatusBadRequest, "invalid session")
		return
	}

	if sess.PaymentStatus != stripe.CheckoutSessionPaymentStatusPaid {
		response.Error(w, http.StatusPaymentRequired, "payment not completed")
		return
	}

	if sess.Metadata["type"] != "donation" {
		response.Error(w, http.StatusBadRequest, "invalid session type")
		return
	}

	donorID, err1 := uuid.Parse(sess.Metadata["donor_id"])
	creatorID, err2 := uuid.Parse(sess.Metadata["creator_id"])
	amountCents, err3 := strconv.Atoi(sess.Metadata["amount"])
	if err1 != nil || err2 != nil || err3 != nil {
		response.Error(w, http.StatusBadRequest, "invalid session metadata")
		return
	}

	if donorID != claims.UserID {
		response.Error(w, http.StatusForbidden, "forbidden")
		return
	}

	msg := sess.Metadata["message"]
	var msgPtr *string
	if msg != "" {
		msgPtr = &msg
	}
	sessionID := body.SessionID

	if _, err := h.donationRepo.Create(r.Context(), donorID, creatorID, amountCents, msgPtr, &sessionID); err != nil {
		log.Printf("donation create error: %v", err)
		response.Error(w, http.StatusInternalServerError, "failed to record donation")
		return
	}
	go h.notifyDonationReceived(donorID, creatorID, amountCents)

	response.OK(w, map[string]string{"status": "ok"})
}

// CreateSubscriptionIntent — POST /api/creators/{username}/checkout-intent
// Mobile: creates a Checkout Session with a deep-link success URL.
func (h *StripeHandler) CreateSubscriptionIntent(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	if claims == nil {
		response.Error(w, http.StatusUnauthorized, "unauthorized")
		return
	}

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

	if profile.SubscriptionPriceCents > 9_999_999 {
		response.Error(w, http.StatusBadRequest, "subscription price exceeds maximum allowed (9 999 999 ₸)")
		return
	}
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
		SuccessURL: stripe.String("xabarlaapp://payment?type=subscription&session_id={CHECKOUT_SESSION_ID}"),
		CancelURL:  stripe.String("xabarlaapp://payment?type=cancelled"),
		Metadata: map[string]string{
			"patron_id":  claims.UserID.String(),
			"creator_id": creatorUser.ID.String(),
		},
	}

	sess, err := session.New(params)
	if err != nil {
		log.Printf("stripe checkout-intent error: %v", err)
		response.Error(w, http.StatusInternalServerError, "failed to create checkout session")
		return
	}

	response.OK(w, map[string]string{"url": sess.URL})
}

// CreateDonationIntent — POST /api/creators/{username}/donate-intent
// Mobile: creates a donation Checkout Session with a deep-link success URL.
func (h *StripeHandler) CreateDonationIntent(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	if claims == nil {
		response.Error(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	username := chi.URLParam(r, "username")

	var body struct {
		AmountCents int    `json:"amount_cents"`
		Message     string `json:"message"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.AmountCents <= 0 {
		response.Error(w, http.StatusBadRequest, "amount_cents is required and must be positive")
		return
	}

	creatorUser, err := h.userRepo.GetByUsername(r.Context(), username)
	if err != nil {
		response.Error(w, http.StatusNotFound, "creator not found")
		return
	}

	if creatorUser.ID == claims.UserID {
		response.Error(w, http.StatusBadRequest, "cannot donate to yourself")
		return
	}

	profile, err := h.creatorRepo.GetByUserID(r.Context(), creatorUser.ID)
	if err != nil {
		response.Error(w, http.StatusNotFound, "creator profile not found")
		return
	}

	if body.AmountCents > 9_999_999 {
		response.Error(w, http.StatusBadRequest, "donation amount exceeds maximum allowed (9 999 999 ₸)")
		return
	}
	amountTiyn := int64(body.AmountCents) * 100

	params := &stripe.CheckoutSessionParams{
		Mode: stripe.String(string(stripe.CheckoutSessionModePayment)),
		LineItems: []*stripe.CheckoutSessionLineItemParams{
			{
				PriceData: &stripe.CheckoutSessionLineItemPriceDataParams{
					Currency:   stripe.String("kzt"),
					UnitAmount: stripe.Int64(amountTiyn),
					ProductData: &stripe.CheckoutSessionLineItemPriceDataProductDataParams{
						Name: stripe.String("Донат для " + profile.DisplayName),
					},
				},
				Quantity: stripe.Int64(1),
			},
		},
		SuccessURL: stripe.String("xabarlaapp://payment?type=donation&session_id={CHECKOUT_SESSION_ID}"),
		CancelURL:  stripe.String("xabarlaapp://payment?type=cancelled"),
		Metadata: map[string]string{
			"type":       "donation",
			"donor_id":   claims.UserID.String(),
			"creator_id": creatorUser.ID.String(),
			"amount":     strconv.Itoa(body.AmountCents),
			"message":    body.Message,
		},
	}

	sess, err := session.New(params)
	if err != nil {
		log.Printf("stripe donate-intent error: %v", err)
		response.Error(w, http.StatusInternalServerError, "failed to create checkout session")
		return
	}

	response.OK(w, map[string]string{"url": sess.URL})
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

		if sess.Metadata["type"] == "donation" {
			donorID, err1 := uuid.Parse(sess.Metadata["donor_id"])
			creatorID, err2 := uuid.Parse(sess.Metadata["creator_id"])
			amountCents, err3 := strconv.Atoi(sess.Metadata["amount"])
			if err1 != nil || err2 != nil || err3 != nil {
				log.Printf("stripe: invalid donation metadata")
				w.WriteHeader(http.StatusOK)
				return
			}
			msg := sess.Metadata["message"]
			var msgPtr *string
			if msg != "" {
				msgPtr = &msg
			}
			sid := sess.ID
			if _, err := h.donationRepo.Create(r.Context(), donorID, creatorID, amountCents, msgPtr, &sid); err != nil {
				log.Printf("stripe: failed to create donation: %v", err)
			} else {
				log.Printf("stripe: donation recorded donor=%s creator=%s amount=%d", donorID, creatorID, amountCents)
				go h.notifyDonationReceived(donorID, creatorID, amountCents)
			}
		} else {
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
				go h.notifyNewSubscriber(patronID, creatorID)
			}
		}
	}

	w.WriteHeader(http.StatusOK)
}

func (h *StripeHandler) notifyNewSubscriber(patronID, creatorID uuid.UUID) {
	ctx := context.Background()
	patron, err := h.userRepo.GetByID(ctx, patronID)
	if err != nil {
		return
	}
	title := fmt.Sprintf("%s оформил платную подписку на вас", patron.Username)
	link := fmt.Sprintf("/%s", patron.Username)
	event := hub.Event{Type: "new_subscriber", Title: title, Link: link}
	h.notifHub.Send(creatorID, event)
	n, err := h.notifRepo.Create(ctx, creatorID, "new_subscriber", title, nil, &link)
	if err == nil {
		event.ID = n.ID.String()
	}
}

func (h *StripeHandler) notifyDonationReceived(donorID, creatorID uuid.UUID, amountCents int) {
	ctx := context.Background()
	donor, err := h.userRepo.GetByID(ctx, donorID)
	if err != nil {
		return
	}
	title := fmt.Sprintf("%s отправил вам донат %d ₸", donor.Username, amountCents)
	link := fmt.Sprintf("/%s", donor.Username)
	body := fmt.Sprintf("%d ₸", amountCents)
	event := hub.Event{Type: "donation_received", Title: title, Body: body, Link: link}
	h.notifHub.Send(creatorID, event)
	n, err := h.notifRepo.Create(ctx, creatorID, "donation_received", title, &body, &link)
	if err == nil {
		event.ID = n.ID.String()
	}
}
