package dto

import "../../dto/time"

type CreateCommentRequest struct {
	Body     string `json:"body" validate:"required"`
	ParentID *uint  `json:"parent_id,omitempty"`
}

type UpdateCommentRequest struct {
	Body string `json:"body" validate:"required"`
}

type CommentResponse struct {
	CommentID uint       `json:"comment_id"`
	PostID    uint       `json:"post_id"`
	UserID    uint       `json:"user_id"`
	ParentID  *uint      `json:"parent_id,omitempty"`
	Body      string     `json:"body"`
	Status    string     `json:"status"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt *time.Time `json:"updated_at,omitempty"`
}

type ListCommentsResponse struct {
	PostID    uint              `json:"post_id"`
	ParentID  *uint             `json:"parent_id,omitempty"`
	Limit     int               `json:"limit"`
	Offset    int               `json:"offset"`
	Total     int64             `json:"total"`
	Comments  []CommentResponse `json:"comments"`
	Replies   []CommentNode   `json:"replies,omitempty"`
	Count     int64             `json:"count"` // same as len(Comments)
}

type CommentNode struct {
	Comment CommentResponse `json:"comment"`
	Replies []CommentNode   `json:"replies,omitempty"`
}
