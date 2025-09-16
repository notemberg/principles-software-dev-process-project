package user

import "github.com/RathaTart/FoodBridge/dto"

type Service interface {
	Register(req dto.RegisterRequest) (*dto.UserResponse, error)
	Login(req dto.LoginRequest) (*dto.UserResponse, error)
	GetByID(id uint) (*dto.UserResponse, error)
	UpdateProfile(id uint, req dto.UpdateProfileRequest) (*dto.UserResponse, error)
}
