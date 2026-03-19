package service

import (
	"context"
	"errors"
	"fmt"

	"diploma/backend/internal/hub"
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
	postRepo   *repository.PostRepo
	subRepo    *repository.SubscriptionRepo
	notifRepo  *repository.NotificationRepo
	hub        *hub.Hub
}

func NewPostService(postRepo *repository.PostRepo, subRepo *repository.SubscriptionRepo, notifRepo *repository.NotificationRepo, h *hub.Hub) *PostService {
	return &PostService{postRepo: postRepo, subRepo: subRepo, notifRepo: notifRepo, hub: h}
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

func (s *PostService) Unpublish(ctx context.Context, postID, requesterID uuid.UUID) (*models.Post, error) {
	post, err := s.postRepo.GetByID(ctx, postID)
	if err != nil {
		return nil, mapRepoErr(err)
	}
	if post.CreatorID != requesterID {
		return nil, ErrForbidden
	}
	return s.postRepo.Unpublish(ctx, postID)
}

func (s *PostService) Publish(ctx context.Context, postID, requesterID uuid.UUID) (*models.Post, error) {
	post, err := s.postRepo.GetByID(ctx, postID)
	if err != nil {
		return nil, mapRepoErr(err)
	}
	if post.CreatorID != requesterID {
		return nil, ErrForbidden
	}

	published, err := s.postRepo.Publish(ctx, postID)
	if err != nil {
		return nil, err
	}

	// Берём имя автора из первого запроса (там есть Creator)
	creatorName := ""
	if post.Creator != nil {
		creatorName = post.Creator.Username
	}

	// Уведомляем подписчиков и фолловеров асинхронно
	go s.notifyFollowers(post.CreatorID, published.ID.String(), published.Title, creatorName)

	return published, nil
}

func (s *PostService) notifyFollowers(creatorID uuid.UUID, postID, postTitle, creatorName string) {
	ctx := context.Background()
	recipientIDs, err := s.notifRepo.GetFollowerAndSubscriberIDs(ctx, creatorID)
	if err != nil || len(recipientIDs) == 0 {
		return
	}

	if creatorName == "" {
		creatorName = "Автор"
	}

	title := fmt.Sprintf("%s опубликовал новый пост", creatorName)
	link := fmt.Sprintf("/posts/%s", postID)

	// Сначала отправляем SSE всем подключённым — без задержки БД
	event := hub.Event{
		Type:  "new_post",
		Title: title,
		Body:  postTitle,
		Link:  link,
		ID:    postID,
	}
	s.hub.SendMany(recipientIDs, event)

	// Потом сохраняем в БД
	for _, uid := range recipientIDs {
		n, err := s.notifRepo.Create(ctx, uid, "new_post", title, &postTitle, &link)
		if err == nil {
			// Обновляем ID события на реальный UUID из БД
			event.ID = n.ID.String()
		}
	}
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

// GetOwn — получить пост только если requester — автор
func (s *PostService) GetOwn(ctx context.Context, postID, requesterID uuid.UUID) (*models.Post, error) {
	post, err := s.postRepo.GetByID(ctx, postID)
	if err != nil {
		return nil, mapRepoErr(err)
	}
	if post.CreatorID != requesterID {
		return nil, ErrForbidden
	}
	return post, nil
}

func (s *PostService) AddAttachment(ctx context.Context, postID uuid.UUID, url, mimeType string, size int64) (*models.PostAttachment, error) {
	return s.postRepo.AddAttachment(ctx, postID, url, mimeType, size)
}

func (s *PostService) DeleteAttachment(ctx context.Context, attachmentID, requesterID uuid.UUID) error {
	return s.postRepo.DeleteAttachment(ctx, attachmentID, requesterID)
}

func mapRepoErr(err error) error {
	if errors.Is(err, repository.ErrNotFound) {
		return ErrNotFound
	}
	return err
}
