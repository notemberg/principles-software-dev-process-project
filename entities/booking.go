package entities

import "time"

type Status string

const (
	StatusPending   Status = "PENDING"
	StatusCancelled Status = "CANCELLED"
	StatusCompleted Status = "COMPLETED"
	StatusExpired   Status = "EXPIRED"
)

type Booking struct {
	BookingID      int64      `json:"booking_id"`
	PostID         int64      `json:"post_id"`
	ReceiverUserID int64      `json:"receiver_user_id"`
	Status         Status     `json:"status"`
	ExpireAt       *time.Time `json:"expire_at,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
	QRToken        *string    `json:"qr_token,omitempty"`
}

// Minimal stock view of a Post for reservation logic.
type PostDetail struct {
	PostID       int64
	QtyAvailable int
}