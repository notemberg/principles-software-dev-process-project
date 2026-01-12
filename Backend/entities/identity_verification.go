package entities

import "../../entities/time"

type VerificationStatus string

const (
    VerificationPending  VerificationStatus = "PENDING"
    VerificationApproved VerificationStatus = "APPROVED"
    VerificationRejected VerificationStatus = "REJECTED"
)

type Verification struct {
    VerificationID  uint               `gorm:"primaryKey"`
    UserID          uint               `gorm:"index;not null"`
    IDCardImageURL  string             `gorm:"type:text;not null"`
    Status          VerificationStatus `gorm:"type:varchar(20);not null;default:'PENDING';index"`
    Note            string             `gorm:"type:text"` // เหตุผลที่ reject (ถ้ามี)
    ReviewedBy      *uint              `gorm:"index"`     // admin user_id
    ReviewedAt      *time.Time

    CreatedAt time.Time
    UpdatedAt time.Time
}
