package user

import "github.com/RathaTart/FoodBridge/dto"

type Service interface {
    Login(req dto.LoginRequest) (*dto.AuthResponse, error)
    Register(req dto.RegisterRequest) (*dto.UserResponse, error)
    GetByID(id uint) (*dto.UserResponse, error)
    UpdateProfile(id uint, req dto.UpdateMeRequest) (*dto.UserResponse, error)
}
