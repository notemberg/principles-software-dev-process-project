package comment

import (
	"context"

	"github.com/RathaTart/FoodBridge/dto"
)

type Service interface {
	Create(ctx context.Context, postID, userID uint, req dto.CreateCommentRequest) (*dto.CommentResponse, error)
	Update(ctx context.Context, commentID, userID uint, req dto.UpdateCommentRequest) (*dto.CommentResponse, error)
	Delete(ctx context.Context, commentID, userID uint) error
	List(ctx context.Context, postID uint, parentID *uint, limit, offset int, includeChildren bool) (*dto.ListCommentsResponse, error)

}
