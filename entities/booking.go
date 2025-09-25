package entities

import "time"

type BookingStatus string

const (
	BookingPending   BookingStatus = "PENDING"
	BookingCancelled BookingStatus = "CANCELLED"
	BookingCompleted BookingStatus = "COMPLETED"
	BookingExpired   BookingStatus = "EXPIRED"
)

type Booking struct {
	BookingID      int64         `gorm:"primaryKey;column:booking_id" json:"booking_id"`
	PostID         int64         `gorm:"column:post_id;not null" json:"post_id"`
	ReceiverUserID int64         `gorm:"column:receiver_user_id;not null" json:"receiver_user_id"`
	Status         BookingStatus `gorm:"type:booking_status;default:PENDING;not null" json:"status"`
	ExpireAt       *time.Time    `gorm:"column:expire_at" json:"expire_at,omitempty"`
	CreatedAt      time.Time     `gorm:"column:created_at;autoCreateTime" json:"created_at"`
	QRToken        *string       `gorm:"column:qr_token" json:"qr_token,omitempty"`
}

func (Booking) TableName() string { return "bookings" }
