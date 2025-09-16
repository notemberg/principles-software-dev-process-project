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

type UpdateProfileRequest struct {
	FullName  *string `json:"full_name"`
	AvatarURL *string `json:"avatar_url"`
}

type UserResponse struct {
	UserID     uint    `json:"user_id"`
	Phone      string  `json:"phone"`
	Email      *string `json:"email"`
	FullName   string  `json:"full_name"`
	AvatarURL  *string `json:"avatar_url"`
	IsVerified bool    `json:"is_verified"`
}
