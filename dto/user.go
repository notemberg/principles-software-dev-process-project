package user

type RegisterRequest struct {
	Phone    string  `json:"phone" binding:"required"`
	Email    *string `json:"email"`              // optional
	Password string  `json:"password" binding:"required,min=8"`
	FullName string  `json:"full_name" binding:"required"`
}

type LoginRequest struct {
	Login    string `json:"login" binding:"required"`   // phone หรือ email
	Password string `json:"password" binding:"required"`
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
