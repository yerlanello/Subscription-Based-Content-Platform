package service

import (
	"context"
	"errors"

	"diploma/backend/internal/models"
	"diploma/backend/internal/repository"

	"github.com/google/uuid"
)

var (
	ErrForbidden   = errors.New("forbidden")
	ErrNotFound    = errors.New("not found")
	ErrAccessDenied = errors.New("subscription required")
)

type PostService struct {
	postRepo *repository.PostRepo
	subRepo  *repository.SubscriptionRepo
}

func NewPostService(postRepo *repository.PostRepo, subRepo *repository.SubscriptionRepo) *PostService {
	return &PostService{postRepo: postRepo, subRepo: subRepo}
}

type CreatePostInput struct {
	CreatorID uuid.UUID
	Title     string
	Content   *string
	Type      models.PostType
	IsFree    bool
}

func (s *PostService) Create(ctx context.Context, input CreatePostInput) (*models.Post, error) {
	return s.postRepo.Create(ctx, input.CreatorID, input.Title, input.Content, input.Type, input.IsFree)
}

func (s *PostService) Update(ctx context.Context, postID, requesterID uuid.UUID, title, content *string, isFree *bool) (*models.Post, error) {
	post, err := s.postRepo.GetByID(ctx, postID)
	if err != nil {
		return nil, mapRepoErr(err)
	}
	if post.CreatorID != requesterID {
		return nil, ErrForbidden
	}
	return s.postRepo.Update(ctx, postID, title, content, isFree)
}

func (s *PostService) Publish(ctx context.Context, postID, requesterID uuid.UUID) (*models.Post, error) {
	post, err := s.postRepo.GetByID(ctx, postID)
	if err != nil {
		return nil, mapRepoErr(err)
	}
	if post.CreatorID != requesterID {
		return nil, ErrForbidden
	}
	return s.postRepo.Publish(ctx, postID)
}

func (s *PostService) Delete(ctx context.Context, postID, requesterID uuid.UUID) error {
	post, err := s.postRepo.GetByID(ctx, postID)
	if err != nil {
		return mapRepoErr(err)
	}
	if post.CreatorID != requesterID {
		return ErrForbidden
	}
	return s.postRepo.Delete(ctx, postID)
}

// Get возвращает пост если у requesterID есть доступ.
// requesterID может быть uuid.Nil (гость).
func (s *PostService) Get(ctx context.Context, postID, requesterID uuid.UUID) (*models.Post, error) {
	post, err := s.postRepo.GetByID(ctx, postID)
	if err != nil {
		return nil, mapRepoErr(err)
	}

	if !post.IsPublished && post.CreatorID != requesterID {
		return nil, ErrNotFound
	}

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

	// Загружаем лайки
	post.LikesCount, _ = s.postRepo.LikesCount(ctx, postID)
	if requesterID != uuid.Nil {
		post.IsLiked, _ = s.postRepo.IsLiked(ctx, postID, requesterID)
	}

	attachments, _ := s.postRepo.GetAttachments(ctx, postID)
	post.Attachments = attachments

	return post, nil
}

// ListByCreator — список постов автора с учётом прав
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

	// Для платных постов к которым нет доступа — затираем контент
	for i := range posts {
		if !posts[i].IsFree && !isOwner && !subscribed {
			posts[i].Content = nil
			posts[i].Attachments = nil
		}
	}
	return posts, nil
}

func (s *PostService) Feed(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Post, error) {
	return s.postRepo.Feed(ctx, userID, limit, offset)
}

func (s *PostService) Like(ctx context.Context, postID, userID uuid.UUID) error {
	return s.postRepo.Like(ctx, postID, userID)
}

func (s *PostService) Unlike(ctx context.Context, postID, userID uuid.UUID) error {
	return s.postRepo.Unlike(ctx, postID, userID)
}

func mapRepoErr(err error) error {
	if errors.Is(err, repository.ErrNotFound) {
		return ErrNotFound
	}
	return err
}
