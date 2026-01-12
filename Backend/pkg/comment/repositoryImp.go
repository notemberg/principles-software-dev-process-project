package comment

import (
	"context"
	"time"

	"github.com/RathaTart/FoodBridge/entities"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type gormRepo struct{ db *gorm.DB }

func NewRepository(db *gorm.DB) Repo { return &gormRepo{db: db} }

func (r *gormRepo) Create(ctx context.Context, c *entities.PostComment) error {
	return r.db.WithContext(ctx).Create(c).Error
}

func (r *gormRepo) FindByID(ctx context.Context, id uint) (*entities.PostComment, error) {
	var pc entities.PostComment
	// rely on GORM primaryKey tag (comment_id) automatically
	if err := r.db.WithContext(ctx).First(&pc, id).Error; err != nil {
		return nil, err
	}
	return &pc, nil
}

func (r *gormRepo) UpdateBody(ctx context.Context, id uint, body string) error {
	now := time.Now()
	return r.db.WithContext(ctx).
		Model(&entities.PostComment{}).
		Where("comment_id = ? AND status = 'visible'", id).
		Updates(map[string]interface{}{"body": body, "updated_at": &now}).Error
}

func (r *gormRepo) SoftDelete(ctx context.Context, id uint) (bool, error) {
	// Return whether it was visible before deletion
	var pc entities.PostComment
	if err := r.db.WithContext(ctx).
		Clauses(clause.Locking{Strength: "UPDATE"}).
		Where("comment_id = ?", id).
		First(&pc).Error; err != nil {
		return false, err
	}
	if pc.Status == "deleted" && pc.DeletedAt != nil {
		return false, nil // already deleted, no counter change
	}
	now := time.Now()
	err := r.db.WithContext(ctx).
		Model(&entities.PostComment{}).
		Where("comment_id = ?", id).
		Updates(map[string]interface{}{"status": "deleted", "deleted_at": &now}).Error
	return pc.Status == "visible", err
}

func (r *gormRepo) SoftDeleteCascade(ctx context.Context, rootID uint) (uint, int64, error) {
	// 1) Load root to get post_id
	var root entities.PostComment
	if err := r.db.WithContext(ctx).Where("comment_id = ?", rootID).First(&root).Error; err != nil {
		return 0, 0, err
	}

	// 2) BFS to collect all descendant ids
	ids := []uint{rootID}
	cur := []uint{rootID}
	for len(cur) > 0 {
		children, err := r.listChildrenByParents(ctx, root.PostID, cur)
		if err != nil { return 0, 0, err }
		if len(children) == 0 { break }
		next := make([]uint, 0, len(children))
		for _, ch := range children {
			ids = append(ids, ch.CommentID)
			next = append(next, ch.CommentID)
		}
		cur = next
	}

	// 3) Soft delete only visible ones, count affected
	now := time.Now()
	tx := r.db.WithContext(ctx).
		Model(&entities.PostComment{}).
		Where("comment_id IN ? AND status = 'visible'", ids).
		Updates(map[string]any{
			"status":     "deleted",
			"deleted_at": &now,
		})

	return root.PostID, tx.RowsAffected, tx.Error
}

func (r *gormRepo) ListByPost(ctx context.Context, postID uint, parentID *uint, limit, offset int) ([]entities.PostComment, int64, error) {
	dbx := r.db.WithContext(ctx).Model(&entities.PostComment{}).Where("post_id = ? AND status = 'visible'", postID)
	if parentID == nil {
		dbx = dbx.Where("parent_id IS NULL")
	} else {
		dbx = dbx.Where("parent_id = ?", *parentID)
	}
	var total int64
	if err := dbx.Count(&total).Error; err != nil { return nil, 0, err }

	if limit > 0 { dbx = dbx.Limit(limit) }
	if offset > 0 { dbx = dbx.Offset(offset) }
	dbx = dbx.Order("created_at ASC")

	var rows []entities.PostComment
	if err := dbx.Find(&rows).Error; err != nil { return nil, 0, err }
	return rows, total, nil
}

func (r *gormRepo) IncPostCommentCount(ctx context.Context, postID uint, delta int) error {
	return r.db.WithContext(ctx).
		Model(&entities.Post{}).
		Clauses(clause.Locking{Strength: "UPDATE"}).
		Where("post_id = ?", postID).
		Update("comment_count", gorm.Expr("GREATEST(0, comment_count + ?)", delta)).Error
}

func (r *gormRepo) CountVisibleByPost(ctx context.Context, postID uint) (int64, error) {
	var n int64
	err := r.db.WithContext(ctx).
		Model(&entities.PostComment{}).
		Where("post_id = ? AND status = 'visible'", postID).
		Count(&n).Error
	return n, err
}

// List direct children for a set of parents (visible only)
func (r *gormRepo) listChildrenByParents(ctx context.Context, postID uint, parentIDs []uint) ([]entities.PostComment, error) {
	if len(parentIDs) == 0 { return nil, nil }
	var rows []entities.PostComment
	if err := r.db.WithContext(ctx).
		Where("post_id = ? AND status = 'visible' AND parent_id IN ?", postID, parentIDs).
		Order("created_at ASC").
		Find(&rows).Error; err != nil {
		return nil, err
	}
	return rows, nil
}
