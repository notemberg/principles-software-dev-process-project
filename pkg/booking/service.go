package booking

import (
	"context"
	"time"

	"github.com/RathaTart/FoodBridge/entities"
)

type Config struct {
	HoldTTL    time.Duration
	QRTokenTTL time.Duration
	QRSecret   []byte
}

type Service interface {
	Create(ctx context.Context, postID, receiverUserID int64) (*entities.Booking, error)
	Get(ctx context.Context, bookingID int64) (*entities.Booking, error)
	List(ctx context.Context, f Filter) ([]entities.Booking, error)
	UpdateStatus(ctx context.Context, bookingID int64, newStatus entities.BookingStatus) (*entities.Booking, error)
	IssueQR(ctx context.Context, bookingID int64) (string, error)
	ScanQR(ctx context.Context, token string) (*entities.Booking, error)
	ExpireJob(ctx context.Context, now time.Time) error
}
