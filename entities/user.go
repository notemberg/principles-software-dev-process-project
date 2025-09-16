package entities

import (
	"time"
)

type User struct {
	UserID       uint       `gorm:"primaryKey;column:user_id"`
	Phone        string     `gorm:"size:20;uniqueIndex;not null"`
	Email        *string    `gorm:"size:255;uniqueIndex"`      // nullable
	PasswordHash string     `gorm:"not null"`
	FullName     string     `gorm:"size:100;not null"`
	AvatarURL    *string    `gorm:"size:512"`                  // nullable
	IsVerified   bool       `gorm:"default:false;not null"`    // ผ่าน KYC/verification หรือยัง
	LastLoginAt  *time.Time `gorm:"column:last_login_at"`
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

func (User) TableName() string { return "users" }
