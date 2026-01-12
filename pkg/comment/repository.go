package comment

import (
	"context"

	"github.com/RathaTart/FoodBridge/entities"
)

type Repo interface {
	// CRUD-ish primitives
	Create(ctx context.Context, c *entities.PostComment) error
	FindByID(ctx context.Context, id uint) (*entities.PostComment, error)
	UpdateBody(ctx context.Context, id uint, body string) error

	// Deletion
	// SoftDelete returns (wasVisible, error)
	SoftDelete(ctx context.Context, id uint) (bool, error)
	// SoftDeleteCascade soft-deletes root and all descendants.
	// Returns (postID, affectedVisibleRows, error).
	SoftDeleteCascade(ctx context.Context, rootID uint) (uint, int64, error)

	// Listing
	ListByPost(ctx context.Context, postID uint, parentID *uint, limit, offset int) ([]entities.PostComment, int64, error)

	// Counters
	IncPostCommentCount(ctx context.Context, postID uint, delta int) error
	CountVisibleByPost(ctx context.Context, postID uint) (int64, error)
}
