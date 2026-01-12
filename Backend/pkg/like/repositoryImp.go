package like

import (
	"context"

	"github.com/RathaTart/FoodBridge/entities"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type gormRepo struct{ db *gorm.DB }

func NewRepository(db *gorm.DB) Repo { return &gormRepo{db: db} }

func (r *gormRepo) FindLike(ctx context.Context, postID, userID uint) (*entities.PostLike, error) {
	var l entities.PostLike
	err := r.db.WithContext(ctx).Where("post_id = ? AND user_id = ?", postID, userID).First(&l).Error
	if err != nil { return nil, err }
	return &l, nil
}

func (r *gormRepo) CreateLike(ctx context.Context, l *entities.PostLike) error {
	return r.db.WithContext(ctx).Create(l).Error
}

func (r *gormRepo) DeleteLike(ctx context.Context, postID, userID uint) error {
	return r.db.WithContext(ctx).Where("post_id = ? AND user_id = ?", postID, userID).Delete(&entities.PostLike{}).Error
}

func (r *gormRepo) CountLikes(ctx context.Context, postID uint) (int64, error) {
	var n int64
	err := r.db.WithContext(ctx).Model(&entities.PostLike{}).Where("post_id = ?", postID).Count(&n).Error
	return n, err
}

func (r *gormRepo) ListUserIDs(ctx context.Context, postID uint, limit, offset int) ([]uint, int64, error) {
	var rows []struct{ UserID uint }
	query := r.db.WithContext(ctx).
		Table((entities.PostLike{}).TableName()).
		Select("user_id").
		Where("post_id = ?", postID).
		Order("created_at DESC")
	var total int64
	if err := query.Count(&total).Error; err != nil { return nil, 0, err }
	if limit > 0 { query = query.Limit(limit) }
	if offset > 0 { query = query.Offset(offset) }
	if err := query.Scan(&rows).Error; err != nil { return nil, 0, err }

	userIDs := make([]uint, 0, len(rows))
	for _, r := range rows { userIDs = append(userIDs, r.UserID) }
	return userIDs, total, nil
}

func (r *gormRepo) IncPostLikeCount(ctx context.Context, postID uint, delta int) error {
	return r.db.WithContext(ctx).
		Model(&entities.Post{}).
		Clauses(clause.Locking{Strength: "UPDATE"}).
		Where("post_id = ?", postID).
		Update("like_count", gorm.Expr("GREATEST(0, like_count + ?)", delta)).Error
}
