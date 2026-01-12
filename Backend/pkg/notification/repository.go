package notification

import (
    "context"
    "github.com/RathaTart/FoodBridge/entities"
)

type Repo interface {
    ListByUser(ctx context.Context, userID int64, unreadOnly bool, limit, offset int) ([]entities.Notification, int64, error)
    CountUnread(ctx context.Context, userID int64) (int64, error)
    MarkRead(ctx context.Context, id, userID int64) error
    Delete(ctx context.Context, id, userID int64) error
    Create(ctx context.Context, n *entities.Notification) error
}
