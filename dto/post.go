package dto

import "time"

// ====== Post ======
type CreatePostRequest struct {
	Title       string   `json:"title" validate:"required"`
	Description string   `json:"description"`
	Type        string   `json:"type" validate:"oneof=FREE DISCOUNT COMMUNITY"`
	Price       *int     `json:"price"`    // nil เมื่อ FREE
	Quantity    int      `json:"quantity"` // >=0

	Address string   `json:"address"`
	Lat     *float64 `json:"lat"`
	Lng     *float64 `json:"lng"`

	AvailableFrom *time.Time `json:"available_from"`
	AvailableTo   *time.Time `json:"available_to"`
}

type UpdatePostRequest struct {
	Title       *string   `json:"title"`
	Description *string   `json:"description"`
	Type        *string   `json:"type"`   // oneof
	Price       *int      `json:"price"`
	Quantity    *int      `json:"quantity"`
	Status      *string   `json:"status"` // OPEN/CLOSED
	Address     *string   `json:"address"`
	Lat         *float64  `json:"lat"`
	Lng         *float64  `json:"lng"`
	AvailableFrom *time.Time `json:"available_from"`
	AvailableTo   *time.Time `json:"available_to"`
}

type PostResponse struct {
	PostID      uint    `json:"post_id"`
	ProviderID  uint    `json:"provider_id"`
	Title       string  `json:"title"`
	Description string  `json:"description"`
	Type        string  `json:"type"`
	Price       *int    `json:"price"`
	Quantity    int     `json:"quantity"`
	Status      string  `json:"status"`
	Address     string  `json:"address"`
	Lat         *float64 `json:"lat"`
	Lng         *float64 `json:"lng"`
	AvailableFrom *int64 `json:"available_from,omitempty"`
	AvailableTo   *int64 `json:"available_to,omitempty"`
	CreatedAt   int64   `json:"created_at"`
	UpdatedAt   int64   `json:"updated_at"`
}

type ListPostsQuery struct {
	Page     int     `query:"page"`
	PageSize int     `query:"page_size"`
	Q        string  `query:"q"`           // ค้น title/description
	Type     *string `query:"type"`        // FREE|DISCOUNT|COMMUNITY
	Status   *string `query:"status"`      // OPEN|CLOSED
	Mine     *bool   `query:"mine"`        // true = เฉพาะของเรา (provider_id == uid)
	Sort     string  `query:"sort"`        // created_at|-created_at|title|-title
}

// ====== PostDetail ======
type CreatePostDetailRequest struct {
	ItemName string    `json:"item_name" validate:"required"`
	Qty      int       `json:"qty"`
	Unit     string    `json:"unit"`
	Note     string    `json:"note"`
	ExpireAt *time.Time `json:"expire_at"`
}
type UpdatePostDetailRequest struct {
	ItemName *string    `json:"item_name"`
	Qty      *int       `json:"qty"`
	Unit     *string    `json:"unit"`
	Note     *string    `json:"note"`
	ExpireAt *time.Time `json:"expire_at"`
}

type PostDetailResponse struct {
	PostDetailID uint   `json:"post_detail_id"`
	PostID       uint   `json:"post_id"`
	ItemName     string `json:"item_name"`
	Qty          int    `json:"qty"`
	Unit         string `json:"unit"`
	Note         string `json:"note"`
	ExpireAt     *int64 `json:"expire_at,omitempty"`
	CreatedAt    int64  `json:"created_at"`
	UpdatedAt    int64  `json:"updated_at"`
}
