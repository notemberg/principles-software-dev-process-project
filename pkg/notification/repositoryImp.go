package notification

import (
    "context"

    "gorm.io/gorm"
    "github.com/RathaTart/FoodBridge/entities"
)

type gormRepo struct{ db *gorm.DB }

func NewRepository(db *gorm.DB) Repo { return &gormRepo{db: db} }

func (r *gormRepo) ListByUser(ctx context.Context, userID int64, unreadOnly bool, limit, offset int) ([]entities.Notification, int64, error) {
    q := r.db.WithContext(ctx).Model(&entities.Notification{}).Where("user_id = ?", userID)
    if unreadOnly { q = q.Where("is_read = ?", false) }

    var total int64
    if err := q.Count(&total).Error; err != nil { return nil, 0, err }

    var rows []entities.Notification
    if err := q.Order("notification_id DESC").Limit(limit).Offset(offset).Find(&rows).Error; err != nil {
        return nil, 0, err
    }
    return rows, total, nil
}

func (r *gormRepo) CountUnread(ctx context.Context, userID int64) (int64, error) {
    var n int64
    err := r.db.WithContext(ctx).Model(&entities.Notification{}).
        Where("user_id = ? AND is_read = ?", userID, false).
        Count(&n).Error
    return n, err
}

func (r *gormRepo) MarkRead(ctx context.Context, id, userID int64) error {
    res := r.db.WithContext(ctx).Model(&entities.Notification{}).
        Where("notification_id = ? AND user_id = ?", id, userID).
        Update("is_read", true)
    if res.Error != nil { return res.Error }
    if res.RowsAffected == 0 { return gorm.ErrRecordNotFound }
    return nil
}

func (r *gormRepo) Delete(ctx context.Context, id, userID int64) error {
    res := r.db.WithContext(ctx).
        Where("notification_id = ? AND user_id = ?", id, userID).
        Delete(&entities.Notification{})
    if res.Error != nil { return res.Error }
    if res.RowsAffected == 0 { return gorm.ErrRecordNotFound }
    return nil
}

func (r *gormRepo) Create(ctx context.Context, n *entities.Notification) error {
    return r.db.WithContext(ctx).Create(n).Error
}
