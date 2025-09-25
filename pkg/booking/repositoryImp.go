package booking

import (
	"context"
	"errors"

	"github.com/RathaTart/FoodBridge/entities"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type GormRepo struct{ db *gorm.DB }

func NewGormRepo(db *gorm.DB) *GormRepo { return &GormRepo{db: db} }

func (r *GormRepo) WithTx(ctx context.Context, fn func(Repo) error) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		return fn(&GormRepo{db: tx})
	})
}

type postDetailRow struct {
	PostID       int64 `gorm:"column:post_id;primaryKey"`
	QtyAvailable int   `gorm:"column:qty_available"`
}
func (postDetailRow) TableName() string { return "post_details" }

func (r *GormRepo) LockPostDetail(ctx context.Context, postID int64) (*StockView, error) {
	var row postDetailRow
	err := r.db.WithContext(ctx).
		Clauses(clause.Locking{Strength: "UPDATE"}).
		Where("post_id = ?", postID).
		Select("post_id, qty_available").
		Take(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, gorm.ErrRecordNotFound
	}
	if err != nil {
		return nil, err
	}
	return &StockView{PostID: row.PostID, QtyAvailable: row.QtyAvailable}, nil
}

func (r *GormRepo) DecrementQty(ctx context.Context, postID int64, n int) error {
	res := r.db.WithContext(ctx).Exec(
		"UPDATE post_details SET qty_available = qty_available - ? WHERE post_id = ? AND qty_available >= ?",
		n, postID, n,
	)
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return errors.New("out_of_stock")
	}
	return nil
}

func (r *GormRepo) IncrementQty(ctx context.Context, postID int64, n int) error {
	return r.db.WithContext(ctx).Exec(
		"UPDATE post_details SET qty_available = qty_available + ? WHERE post_id = ?",
		n, postID,
	).Error
}

func (r *GormRepo) CreateBooking(ctx context.Context, b *entities.Booking) error {
	return r.db.WithContext(ctx).Create(b).Error
}

func (r *GormRepo) UpdateBooking(ctx context.Context, b *entities.Booking) error {
	return r.db.WithContext(ctx).Save(b).Error
}

func (r *GormRepo) GetBookingByID(ctx context.Context, id int64, forUpdate bool) (*entities.Booking, error) {
	var b entities.Booking
	q := r.db.WithContext(ctx).Where("booking_id = ?", id)
	if forUpdate {
		q = q.Clauses(clause.Locking{Strength: "UPDATE"})
	}
	if err := q.First(&b).Error; err != nil {
		return nil, err
	}
	return &b, nil
}

func (r *GormRepo) ListBookings(ctx context.Context, f Filter) ([]entities.Booking, error) {
	var out []entities.Booking
	q := r.db.WithContext(ctx).Model(&entities.Booking{})
	if f.PostID != nil           { q = q.Where("post_id = ?", *f.PostID) }
	if f.ReceiverUserID != nil   { q = q.Where("receiver_user_id = ?", *f.ReceiverUserID) }
	if f.Status != nil           { q = q.Where("status = ?", *f.Status) }
	if f.ExpiredBefore != nil    { q = q.Where("expire_at IS NOT NULL AND expire_at < ?", *f.ExpiredBefore) }
	if f.Limit > 0               { q = q.Limit(f.Limit) }
	if f.Offset > 0              { q = q.Offset(f.Offset) }
	if err := q.Order("booking_id DESC").Find(&out).Error; err != nil { return nil, err }
	return out, nil
}
