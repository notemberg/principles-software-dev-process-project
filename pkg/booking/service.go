package booking

import (
	"context"
	"time"

	"github.com/RathaTart/FoodBridge/entities"
)

type Config struct {
	DailyLimit int           // default 1
	HoldTTL    time.Duration // default 10 * time.Minute
	DayTZ      *time.Location
	QRSecret   []byte
	QRTokenTTL time.Duration // default 10 * time.Minute
}

type Service interface {
	Create(ctx context.Context, postID int64, receiverUserID int64) (*entities.Booking, error)
	Get(ctx context.Context, id int64) (*entities.Booking, error)
	List(ctx context.Context, f Filter) ([]entities.Booking, error)
	Cancel(ctx context.Context, id int64) error
	Complete(ctx context.Context, id int64) error

	IssueQR(ctx context.Context, id int64, ttl time.Duration) (string, error)
	ScanQR(ctx context.Context, token string) (*entities.Booking, error)
}
