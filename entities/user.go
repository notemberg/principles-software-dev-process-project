package entities

import (
	"time"
)

type User struct {
	UserID       uint    `gorm:"primaryKey"`
	Phone        string  `gorm:"uniqueIndex"`
	Email        *string `gorm:"uniqueIndex"`
	PasswordHash string

	FullName   string
	AvatarURL  *string
	IsVerified bool

	DisplayName string  `gorm:"type:varchar(100)"`
	FirstName   string  `gorm:"type:varchar(100)"`
	LastName    string  `gorm:"type:varchar(100)"`
	Bio         string  `gorm:"type:text"`
	AddressLine string  `gorm:"type:varchar(255)"`
	Province    string  `gorm:"type:varchar(100)"`
	PostalCode  string  `gorm:"type:varchar(10)"`
	Phone2      string  `gorm:"type:varchar(32)"` // เบอร์ในโปรไฟล์ (ถ้าต้องแยกจาก phone login)

	CreatedAt time.Time
	UpdatedAt time.Time
	LastLoginAt *time.Time
}

func (User) TableName() string { return "users" }
