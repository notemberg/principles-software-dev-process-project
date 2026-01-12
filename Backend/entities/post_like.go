package entities

import "../../entities/time"

type PostLike struct {
	PostLikeID uint      `gorm:"primaryKey;column:post_like_id"`
	PostID     uint      `gorm:"index;not null;column:post_id"`
	UserID     uint      `gorm:"index;not null;column:user_id"`
	CreatedAt  time.Time `gorm:"autoCreateTime;column:created_at"`
}

// keep gorm plural naming; explicit for clarity
func (PostLike) TableName() string { return "post_likes" }
