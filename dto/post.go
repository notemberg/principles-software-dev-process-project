package dto

import "time"

// ====== Post ======
type CreatePostRequest struct {
	Title       string   `json:"title" validate:"required"`
	Description string   `json:"description"`

	IsGiveaway bool   `json:"is_giveaway"` // toggle "ต้องการแจกอาหาร"
	Price      *int   `json:"price"`       // 0=free, >0=discount, nil=unknown (community)
	Quantity   *int   `json:"quantity"`    // nil=unknown (community)

	OpenTime *time.Time `json:"open_time"`  // required if is_giveaway=true
	CloseTime *time.Time `json:"close_time"`

	Address string   `json:"address"`
	Lat     *float64 `json:"lat"`
	Lng     *float64 `json:"lng"`
	Phone   string   `json:"phone"` // เบอร์ติดต่อในโพสต์

	Categories []string `json:"categories"` // ["ของคาว","ของหวาน","ผักสด","ของสด"]
	Images     []string `json:"images"`     // url/path รูป
}

type UpdatePostRequest struct {
	Title       *string  `json:"title"`
	Description *string  `json:"description"`

	IsGiveaway *bool    `json:"is_giveaway"`
	Price      *int     `json:"price"`
	Quantity   *int     `json:"quantity"`

	OpenTime  *time.Time `json:"open_time"`
	CloseTime *time.Time `json:"close_time"`

	Status   *string   `json:"status"` // OPEN/CLOSED
	Address  *string   `json:"address"`
	Lat      *float64  `json:"lat"`
	Lng      *float64  `json:"lng"`
	Phone    *string   `json:"phone"`

	Categories *[]string `json:"categories"`
	Images     *[]string `json:"images"`
}


type PostResponse struct {
	PostID     uint    `json:"post_id"`
	ProviderID uint    `json:"provider_id"`
	Title       string  `json:"title"`
	Description string  `json:"description"`

	IsGiveaway bool   `json:"is_giveaway"`
	Price      *int   `json:"price"`
	Quantity   *int   `json:"quantity"`

	OpenTime  *int64 `json:"open_time,omitempty"`
	CloseTime *int64 `json:"close_time,omitempty"`

	Status  string  `json:"status"`
	Address string  `json:"address"`
	Lat     *float64 `json:"lat"`
	Lng     *float64 `json:"lng"`
	Phone   string  `json:"phone"`

	Categories []string `json:"categories"`
	Images     []string `json:"images"`

	CreatedAt int64 `json:"created_at"`
	UpdatedAt int64 `json:"updated_at"`
}

type ListPostsQuery struct {
	Page     int     `query:"page"`
	PageSize int     `query:"page_size"`
	Q        string  `query:"q"`            // title/description
	Status   *string `query:"status"`       // OPEN/CLOSED
	Mine     *bool   `query:"mine"`         // เฉพาะของฉัน (provider_id == uid)
	IsGiveaway *bool `query:"is_giveaway"`  // filter by mode
	Category *string `query:"category"`     // เช่น ของคาว
	Sort     string  `query:"sort"`         // created_at|-created_at|title|-title
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
