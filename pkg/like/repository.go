package like

import (
	"context"

	"github.com/RathaTart/FoodBridge/entities"
)

type Repo interface {
	// Likes
	FindLike(ctx context.Context, postID, userID uint) (*entities.PostLike, error)
	CreateLike(ctx context.Context, l *entities.PostLike) error
	DeleteLike(ctx context.Context, postID, userID uint) error
	CountLikes(ctx context.Context, postID uint) (int64, error)
	ListUserIDs(ctx context.Context, postID uint, limit, offset int) ([]uint, int64, error)

	// Posts (for counter)
	IncPostLikeCount(ctx context.Context, postID uint, delta int) error
}
