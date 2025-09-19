package entities

import "time"

type PostStatus string
const (
	PostStatusOpen   PostStatus = "OPEN"
	PostStatusClosed PostStatus = "CLOSED"
)

type PostType string
const (
	PostTypeFree      PostType = "FREE"      // แจกฟรี
	PostTypeDiscount  PostType = "DISCOUNT"  // ลดราคา
	PostTypeCommunity PostType = "COMMUNITY" // โพสต์บอกต่อ (ไม่การันตี)
)

type Post struct {
	PostID      uint       `gorm:"primaryKey"`
	ProviderID  uint       `gorm:"index;not null"` // FK -> users.user_id
	Title       string     `gorm:"type:varchar(200);not null"`
	Description string     `gorm:"type:text"`
	Type        PostType   `gorm:"type:varchar(20);not null;index"`
	Price       *int       // หน่วยเป็นบาท (ถ้า FREE ให้เป็น nil)
	Quantity    int        `gorm:"default:0"` // จำนวนรวม (ชิ้น/ชุด)
	Status      PostStatus `gorm:"type:varchar(20);not null;default:'OPEN';index"`

	// ตำแหน่ง/ที่อยู่ (optional)
	Address string   `gorm:"type:varchar(255)"`
	Lat     *float64 `gorm:"index"`
	Lng     *float64 `gorm:"index"`

	AvailableFrom *time.Time
	AvailableTo   *time.Time

	CreatedAt time.Time
	UpdatedAt time.Time
}
