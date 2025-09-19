package dto

type RegisterRequest struct {
	Phone    string  `json:"phone"`
	Email    *string `json:"email"`
	Password string  `json:"password"`
	FullName string  `json:"full_name"`
}

type LoginRequest struct {
	Login    string `json:"login"` // phone หรือ email
	Password string `json:"password"`
}

type UpdateMeRequest struct {
	FullName  *string `json:"full_name"`
	Email     *string `json:"email"`
	AvatarURL *string `json:"avatar_url"`
}

type ChangePasswordRequest struct {
	OldPassword         string `json:"old_password"`
	NewPassword         string `json:"new_password"`
	ConfirmNewPassword  string `json:"confirm_new_password"`
}


type UserResponse struct {
	UserID      uint    `json:"user_id"`
	Phone       string  `json:"phone"`
	Email       *string `json:"email,omitempty"`
	FullName    string  `json:"full_name"`
	AvatarURL   *string `json:"avatar_url,omitempty"`
	IsVerified  bool    `json:"is_verified"`
	CreatedAt   int64   `json:"created_at"`
	UpdatedAt   int64   `json:"updated_at"`
	LastLoginAt *int64  `json:"last_login_at,omitempty"`
}

type ShareLinkResponse struct {
	ShareURL string `json:"share_url"`
}

type ListUsersQuery struct {
	Page     int     `query:"page"`
	PageSize int     `query:"page_size"`
	Q        string  `query:"q"`          // ค้นชื่อ/เบอร์/อีเมล
	Verified *bool   `query:"verified"`   // true/false
	Sort     string  `query:"sort"`       // created_at|-created_at|full_name|-full_name
}

type PagedResult[T any] struct {
	Items    []T `json:"items"`
	Total    int64 `json:"total"`
	Page     int   `json:"page"`
	PageSize int   `json:"page_size"`
}
