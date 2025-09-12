package entities

import "time"

type User struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	UserName  string    `gorm:"size:50;uniqueIndex" json:"userName"`
	FullName  string    `gorm:"size:100" json:"fullName"`
	Phone     string    `gorm:"size:20" json:"phone"`
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}
