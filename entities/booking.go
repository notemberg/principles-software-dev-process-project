package entities

import "time"

type BookingStatus string

const (
	BookingQueued    BookingStatus = "QUEUED"
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
	QueuePos       *int          `gorm:"column:queue_pos" json:"queue_pos,omitempty"`
	ExpireAt       *time.Time    `gorm:"column:expire_at" json:"expire_at,omitempty"`
	CreatedAt      time.Time     `gorm:"column:created_at;autoCreateTime" json:"created_at"`
	UpdatedAt      time.Time     `gorm:"column:updated_at;autoUpdateTime" json:"updated_at"`
	QRToken        *string       `gorm:"column:qr_token" json:"qr_token,omitempty"`
	ExpiredAt      *time.Time    `gorm:"column:expired_at" json:"expired_at,omitempty"`
}

func (Booking) TableName() string { return "bookings" }
