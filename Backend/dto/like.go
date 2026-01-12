package dto

type ToggleLikeResponse struct {
	Liked     bool  `json:"liked"`
	LikeCount int64 `json:"like_count"`
	PostID    uint  `json:"post_id"`
	UserID    uint  `json:"user_id"`
}

type ListLikesResponse struct {
	PostID    uint    `json:"post_id"`
	LikeCount int64   `json:"like_count"`
	UserIDs   []uint  `json:"user_ids"`
	Limit     int     `json:"limit"`
	Offset    int     `json:"offset"`
	Total     int64   `json:"total"`
}
