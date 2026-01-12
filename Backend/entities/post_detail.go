package entities

import "../../entities/time"

type PostDetail struct {
	PostDetailID uint   `gorm:"primaryKey"`
	PostID       uint   `gorm:"index;not null"` // FK -> posts.post_id
	ItemName     string `gorm:"type:varchar(200);not null"`
	Qty          int    `gorm:"default:1"`
	Unit         string `gorm:"type:varchar(50)"` // กล่อง, ชุด, ชิ้น ฯลฯ
	Note         string `gorm:"type:text"`
	ExpireAt     *time.Time

	CreatedAt time.Time
	UpdatedAt time.Time
}
