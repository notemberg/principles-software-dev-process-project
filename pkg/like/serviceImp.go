package like

import (
	"context"
	"errors"

	"github.com/RathaTart/FoodBridge/dto"
	"github.com/RathaTart/FoodBridge/entities"
	"gorm.io/gorm"
)

type service struct{ db *gorm.DB; repo Repo }

func NewService(db *gorm.DB, repo Repo) Service { return &service{db: db, repo: repo} }

func (s *service) Toggle(ctx context.Context, postID, userID uint) (*dto.ToggleLikeResponse, error) {
	var out dto.ToggleLikeResponse
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// Rebind repo to use this tx
		r := &gormRepo{db: tx}

		// check exists
		existing, err := r.FindLike(ctx, postID, userID)
		if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}

		liked := false
		if existing != nil && existing.PostLikeID != 0 {
			// delete like
			if err := r.DeleteLike(ctx, postID, userID); err != nil { return err }
			if err := r.IncPostLikeCount(ctx, postID, -1); err != nil { return err }
		} else {
			// create like
			if err := r.CreateLike(ctx, &entities.PostLike{PostID: postID, UserID: userID}); err != nil { return err }
			if err := r.IncPostLikeCount(ctx, postID, +1); err != nil { return err }
			liked = true
		}

		// current count
		count, err := r.CountLikes(ctx, postID)
		if err != nil { return err }

		out = dto.ToggleLikeResponse{
			Liked:     liked,
			LikeCount: count,
			PostID:    postID,
			UserID:    userID,
		}
		return nil
	})
	return &out, err
}

func (s *service) List(ctx context.Context, postID uint, limit, offset int) (*dto.ListLikesResponse, error) {
	userIDs, total, err := s.repo.ListUserIDs(ctx, postID, limit, offset)
	if err != nil { return nil, err }
	count, err := s.repo.CountLikes(ctx, postID)
	if err != nil { return nil, err }
	return &dto.ListLikesResponse{
		PostID:    postID,
		LikeCount: count,
		UserIDs:   userIDs,
		Limit:     limit,
		Offset:    offset,
		Total:     total,
	}, nil
}
