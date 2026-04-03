package handlers

import (
	"net/http"

	"diploma/backend/internal/middleware"
	"diploma/backend/internal/models"
	"diploma/backend/internal/repository"
	"diploma/backend/internal/response"
)

type BillingHandler struct {
	subRepo      *repository.SubscriptionRepo
	donationRepo *repository.DonationRepo
}

func NewBillingHandler(subRepo *repository.SubscriptionRepo, donationRepo *repository.DonationRepo) *BillingHandler {
	return &BillingHandler{subRepo: subRepo, donationRepo: donationRepo}
}

func (h *BillingHandler) History(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)

	subs, err := h.subRepo.GetBillingHistory(r.Context(), claims.UserID)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}

	donations, err := h.donationRepo.GetByDonor(r.Context(), claims.UserID)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}

	if subs == nil {
		subs = []models.BillingSubscription{}
	}
	if donations == nil {
		donations = []models.BillingDonation{}
	}

	response.OK(w, map[string]any{
		"subscriptions": subs,
		"donations":     donations,
	})
}
