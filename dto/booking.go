package dto

import (
	"time"

	"github.com/RathaTart/FoodBridge/entities"
)

type Booking struct {
	BookingID      int64                  `json:"booking_id"`
	PostID         int64                  `json:"post_id"`
	ReceiverUserID int64                  `json:"receiver_user_id"`
	Status         entities.BookingStatus `json:"status"`
	ExpireAt       *time.Time             `json:"expire_at,omitempty"`
	CreatedAt      time.Time              `json:"created_at"`
	QRToken        *string                `json:"qr_token,omitempty"`
}

type UpdateStatusRequest struct {
	Status entities.BookingStatus `json:"status"`
}

type IssueQRResponse struct {
	QRToken string `json:"qr_token"`
}

type ScanQRRequest struct {
	QRToken string `json:"qr_token"`
}

func FromEntity(b *entities.Booking) Booking {
	return Booking{
		BookingID:      b.BookingID,
		PostID:         b.PostID,
		ReceiverUserID: b.ReceiverUserID,
		Status:         b.Status,
		ExpireAt:       b.ExpireAt,
		CreatedAt:      b.CreatedAt,
		QRToken:        b.QRToken,
	}
}

func FromEntities(list []entities.Booking) []Booking {
	out := make([]Booking, 0, len(list))
	for i := range list {
		c := list[i]
		out = append(out, FromEntity(&c))
	}
	return out
}
