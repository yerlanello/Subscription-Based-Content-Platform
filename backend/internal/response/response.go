package response

import (
	"encoding/json"
	"net/http"
)

type envelope map[string]any

func JSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func OK(w http.ResponseWriter, data any) {
	JSON(w, http.StatusOK, envelope{"data": data})
}

func Created(w http.ResponseWriter, data any) {
	JSON(w, http.StatusCreated, envelope{"data": data})
}

func Error(w http.ResponseWriter, status int, message string) {
	JSON(w, status, envelope{"error": message})
}

func NoContent(w http.ResponseWriter) {
	w.WriteHeader(http.StatusNoContent)
}
