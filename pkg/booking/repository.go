package booking

import (
	"context"
	"time"

	"github.com/RathaTart/FoodBridge/entities"
)

type StockView struct {
	PostID       int64
	QtyAvailable int
}

type Filter struct {
	PostID         *int64
	ReceiverUserID *int64
	Status         *entities.BookingStatus
	ExpiredBefore  *time.Time
	Limit          int
	Offset         int
}

type Repo interface {
	WithTx(ctx context.Context, fn func(r Repo) error) error
	LockPostDetail(ctx context.Context, postID int64) (*StockView, error)
	DecrementQty(ctx context.Context, postID int64, n int) error
	IncrementQty(ctx context.Context, postID int64, n int) error
	CreateBooking(ctx context.Context, b *entities.Booking) error
	UpdateBooking(ctx context.Context, b *entities.Booking) error
	GetBookingByID(ctx context.Context, id int64, forUpdate bool) (*entities.Booking, error)
	ListBookings(ctx context.Context, f Filter) ([]entities.Booking, error)
}
