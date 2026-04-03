package recommendation

import (
	"context"
	"log"

	"diploma/backend/internal/models"
	"diploma/backend/internal/repository"

	"github.com/google/uuid"
)

// Service wires together Milvus, the embedding microservice, and PostgreSQL repos.
type Service struct {
	milvus      *MilvusClient
	embedding   *EmbeddingClient
	postRepo    *repository.PostRepo
	creatorRepo *repository.CreatorRepo
}

func NewService(milvus *MilvusClient, embedding *EmbeddingClient, postRepo *repository.PostRepo, creatorRepo *repository.CreatorRepo) *Service {
	return &Service{
		milvus:      milvus,
		embedding:   embedding,
		postRepo:    postRepo,
		creatorRepo: creatorRepo,
	}
}

// IndexPost generates and stores a hybrid vector for a published post.
// Runs in background — errors are logged, never surfaced to the user.
func (s *Service) IndexPost(ctx context.Context, post *models.Post) {
	profile, err := s.creatorRepo.GetByUserID(ctx, post.CreatorID)
	if err != nil {
		log.Printf("rec: get creator profile for post %s: %v", post.ID, err)
		return
	}

	content := ""
	if post.Content != nil {
		content = *post.Content
	}
	category := ""
	if profile != nil && profile.Category != nil {
		category = *profile.Category
	}

	vec, err := s.embedding.EmbedPost(ctx, post.Title, content, category)
	if err != nil {
		log.Printf("rec: embed post %s: %v", post.ID, err)
		return
	}
	if err := s.milvus.UpsertVector(ctx, PostCollection, post.ID.String(), vec); err != nil {
		log.Printf("rec: upsert post %s: %v", post.ID, err)
		return
	}
	log.Printf("rec: indexed post %s", post.ID)
}

// OnLike updates the user's preference vector using exponential moving average
// of the liked post's vector. Runs in background.
func (s *Service) OnLike(ctx context.Context, userID, postID uuid.UUID) {
	postVec, err := s.milvus.GetVector(ctx, PostCollection, postID.String())
	if err != nil || postVec == nil {
		// Post not yet indexed (e.g. was published before rec system) — skip
		log.Printf("rec: post vector not found for %s", postID)
		return
	}

	currentVec, err := s.milvus.GetVector(ctx, UserCollection, userID.String())
	if err != nil {
		log.Printf("rec: get user vector %s: %v", userID, err)
		return
	}

	// currentVec may be nil for a new user — embedding service handles that case
	newVec, err := s.embedding.UpdateUserVector(ctx, currentVec, postVec, 0.3)
	if err != nil {
		log.Printf("rec: update user vector %s: %v", userID, err)
		return
	}

	if err := s.milvus.UpsertVector(ctx, UserCollection, userID.String(), newVec); err != nil {
		log.Printf("rec: upsert user vector %s: %v", userID, err)
	}
}

// Recommend returns personalised posts for the user.
// Falls back to random explore if the user has no preference vector yet
// or if Milvus / embedding service is unavailable.
func (s *Service) Recommend(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Post, error) {
	userVec, err := s.milvus.GetVector(ctx, UserCollection, userID.String())
	if err != nil || userVec == nil {
		log.Printf("rec: no user vector for %s, falling back to explore", userID)
		return s.postRepo.Explore(ctx, limit, offset)
	}

	// Pull top-100 candidates from Milvus ANN search
	candidateIDs, err := s.milvus.SearchSimilar(ctx, PostCollection, userVec, 100)
	if err != nil || len(candidateIDs) == 0 {
		log.Printf("rec: milvus search failed or empty: %v", err)
		return s.postRepo.Explore(ctx, limit, offset)
	}

	// Re-rank in PostgreSQL by (likes * 2 + recency) and apply standard filters
	posts, err := s.postRepo.GetByIDs(ctx, candidateIDs, limit, offset)
	if err != nil || len(posts) == 0 {
		return s.postRepo.Explore(ctx, limit, offset)
	}
	return posts, nil
}
