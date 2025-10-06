package entities

import "time"

type PostComment struct {
	CommentID uint       `gorm:"primaryKey;column:comment_id"`
	PostID    uint       `gorm:"index;not null;column:post_id"`
	UserID    uint       `gorm:"index;not null;column:user_id"`
	ParentID  *uint      `gorm:"index;column:parent_id"` // nil = top-level
	Body      string     `gorm:"type:text;not null;column:body"`
	Status    string     `gorm:"type:text;default:visible;column:status"` // visible|deleted
	CreatedAt time.Time  `gorm:"autoCreateTime;column:created_at"`
	UpdatedAt *time.Time `gorm:"column:updated_at"`
	DeletedAt *time.Time `gorm:"index;column:deleted_at"`
}

func (PostComment) TableName() string { return "post_comments" }
