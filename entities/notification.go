package entities

import (
    "time"
    "gorm.io/datatypes"
)

type Notification struct {
    NotificationID int64          `gorm:"primaryKey;column:notification_id" json:"notification_id"`
    UserID         int64          `gorm:"column:user_id;not null;index" json:"user_id"`
    Title          string         `gorm:"column:title;type:varchar(255);not null" json:"title"`
    Body           string         `gorm:"column:body;type:text" json:"body"`
    Type           string         `gorm:"column:type;type:varchar(50);not null;default:'general'" json:"type"`
    Data           datatypes.JSON `gorm:"column:data;type:jsonb" json:"data,omitempty"`
    IsRead         bool           `gorm:"column:is_read;default:false;not null" json:"is_read"`
    CreatedAt      time.Time      `gorm:"column:created_at;autoCreateTime" json:"created_at"`
    UpdatedAt      time.Time      `gorm:"column:updated_at;autoUpdateTime" json:"updated_at"`
}

func (Notification) TableName() string { return "notifications" }
