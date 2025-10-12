package notification

import (
    "context"
    "github.com/RathaTart/FoodBridge/dto"
)

type Service interface {
    List(ctx context.Context, userID int64, q dto.ListNotificationsQuery) (*dto.ListNotificationsResponse, error)
    UnreadCount(ctx context.Context, userID int64) (int64, error)
    MarkRead(ctx context.Context, id, userID int64) error
    Delete(ctx context.Context, id, userID int64) error
}
