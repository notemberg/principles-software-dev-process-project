package like

import (
	"context"

	"github.com/RathaTart/FoodBridge/dto"
)

type Service interface {
	Toggle(ctx context.Context, postID, userID uint) (*dto.ToggleLikeResponse, error)
	List(ctx context.Context, postID uint, limit, offset int) (*dto.ListLikesResponse, error)
}
