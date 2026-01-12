package notification

import (
    "context"
    "encoding/json"

    "github.com/RathaTart/FoodBridge/dto"
)

type service struct{ repo Repo }

func NewService(repo Repo) Service { return &service{repo: repo} }

func (s *service) List(ctx context.Context, userID int64, q dto.ListNotificationsQuery) (*dto.ListNotificationsResponse, error) {
    page := q.Page; if page <= 0 { page = 1 }
    size := q.PageSize; if size <= 0 || size > 100 { size = 20 }
    offset := (page-1)*size

    rows, total, err := s.repo.ListByUser(ctx, userID, q.Unread, size, offset)
    if err != nil { return nil, err }

    items := make([]dto.NotificationItem, 0, len(rows))
    for _, r := range rows {
        var data any
        if len(r.Data) > 0 { _ = json.Unmarshal([]byte(r.Data), &data) }
        items = append(items, dto.NotificationItem{
            NotificationID: r.NotificationID,
            Title:          r.Title,
            Body:           r.Body,
            Type:           r.Type,
            Data:           data,
            IsRead:         r.IsRead,
            CreatedAt:      r.CreatedAt,
        })
    }
    return &dto.ListNotificationsResponse{ Items: items, Total: total, Limit: size, Offset: offset }, nil
}

func (s *service) UnreadCount(ctx context.Context, userID int64) (int64, error) { return s.repo.CountUnread(ctx, userID) }
func (s *service) MarkRead(ctx context.Context, id, userID int64) error         { return s.repo.MarkRead(ctx, id, userID) }
func (s *service) Delete(ctx context.Context, id, userID int64) error           { return s.repo.Delete(ctx, id, userID) }
