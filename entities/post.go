package entities

import (
	"time"

	"gorm.io/datatypes"
)

type PostStatus string

const (
	PostStatusOpen   PostStatus = "OPEN"
	PostStatusClosed PostStatus = "CLOSED"
)

// NOTE: ตัด PostType เดิมออกแล้ว

type Post struct {
	PostID     uint       `gorm:"primaryKey"`
	ProviderID uint       `gorm:"index;not null"` // FK -> users.user_id

	// Core
	Title       string `gorm:"type:varchar(200);not null"`
	Description string `gorm:"type:text"`

	// โหมดประกาศ
	IsGiveaway bool `gorm:"not null;default:false"` // true=แจก (free/discount), false=community

	// ราคา/จำนวน
	Price    *int `gorm:""` // nil=ไม่ทราบ/ไม่ได้ระบุ (community), 0=ฟรี, >0=ลดราคา
	Quantity *int `gorm:""` // nil=ไม่ทราบ/ไม่ได้ระบุ (community)

	// เวลาเปิด–ปิด (ใช้เมื่อ IsGiveaway=true)
	OpenTime  *time.Time
	CloseTime *time.Time

	// สถานะ (เจ้าของสามารถปิดโพสต์เองได้)
	Status PostStatus `gorm:"type:varchar(20);not null;default:'OPEN';index"`

	// พิกัด/ที่อยู่ + โทรศัพท์ติดต่อโพสต์นี้
	Address string   `gorm:"type:varchar(255)"`
	Lat     *float64 `gorm:"index"`
	Lng     *float64 `gorm:"index"`
	Phone   string   `gorm:"type:varchar(32)"`

	// หมวดหมู่อาหาร (หลายค่า) – เก็บเป็น JSON array ของ string
	Categories datatypes.JSON `gorm:"type:jsonb"` // เช่น ["ของคาว","ของหวาน"]

	// สื่อ (เผื่ออนาคต: เก็บลิงก์ไฟล์รูป)
	Images datatypes.JSON `gorm:"type:jsonb"` // []string

	CreatedAt time.Time
	UpdatedAt time.Time
}
