package recommendation

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

type EmbeddingClient struct {
	baseURL string
	http    *http.Client
}

func NewEmbeddingClient(baseURL string) *EmbeddingClient {
	return &EmbeddingClient{
		baseURL: baseURL,
		http:    &http.Client{Timeout: 15 * time.Second},
	}
}

func (c *EmbeddingClient) EmbedPost(ctx context.Context, title, content, category string) ([]float32, error) {
	body, _ := json.Marshal(map[string]string{
		"title":    title,
		"content":  content,
		"category": category,
	})
	req, err := http.NewRequestWithContext(ctx, "POST", c.baseURL+"/embed", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("embed request: %w", err)
	}
	defer resp.Body.Close()

	var result struct {
		Vector []float32 `json:"vector"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("decode embedding: %w", err)
	}
	return result.Vector, nil
}

func (c *EmbeddingClient) UpdateUserVector(ctx context.Context, currentVec, postVec []float32, alpha float32) ([]float32, error) {
	body, _ := json.Marshal(map[string]interface{}{
		"current_vector": currentVec,
		"post_vector":    postVec,
		"alpha":          alpha,
	})
	req, err := http.NewRequestWithContext(ctx, "POST", c.baseURL+"/user/update", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("user update request: %w", err)
	}
	defer resp.Body.Close()

	var result struct {
		Vector []float32 `json:"vector"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("decode user vector: %w", err)
	}
	return result.Vector, nil
}
