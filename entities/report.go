package entities

import (
	"time"
	"gorm.io/datatypes"
)

type ReportStatus string

const (
	ReportStatusOpen     ReportStatus = "OPEN"
	ReportStatusResolved ReportStatus = "RESOLVED"
	ReportStatusRejected ReportStatus = "REJECTED"
)

type Report struct {
	ReportID   uint          `gorm:"primaryKey"`
	PostID     uint          `gorm:"index;not null"` // FK -> posts.post_id
	ReporterID uint          `gorm:"index;not null"` // FK -> users.user_id

	Title   string         `gorm:"type:varchar(200);not null"` // ปัญหาที่เกิด (หัวข้อ)
	Detail  string         `gorm:"type:text"`                   // รายละเอียดเพิ่มเติม
	Images  datatypes.JSON `gorm:"type:jsonb;default:'[]'::jsonb"`      // []string
	Types   datatypes.JSON `gorm:"type:jsonb;default:'[]'::jsonb"`      // []string เช่น ["USABILITY","PRIVACY","SPAM","OTHER"]

	Status ReportStatus `gorm:"type:varchar(20);not null;default:'OPEN';index"`

	CreatedAt time.Time
	UpdatedAt time.Time
}
