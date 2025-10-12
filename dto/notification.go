package dto

import "time"

type NotificationItem struct {
    NotificationID int64       `json:"notification_id"`
    Title          string      `json:"title"`
    Body           string      `json:"body"`
    Type           string      `json:"type"`
    Data           interface{} `json:"data,omitempty"`
    IsRead         bool        `json:"is_read"`
    CreatedAt      time.Time   `json:"created_at"`
}

type ListNotificationsQuery struct {
    Page     int  `query:"page"`
    PageSize int  `query:"page_size"`
    Unread   bool `query:"unread"`
}

type ListNotificationsResponse struct {
    Items  []NotificationItem `json:"items"`
    Total  int64              `json:"total"`
    Limit  int                `json:"limit"`
    Offset int                `json:"offset"`
}

type UnreadCountResponse struct {
    Unread int64 `json:"unread"`
}
