package user

import "github.com/RathaTart/FoodBridge/dto"

type Service interface {
    Login(req dto.LoginRequest) (*dto.AuthResponse, error)
    Register(req dto.RegisterRequest) (*dto.UserResponse, error)
    GetByID(id uint) (*dto.UserResponse, error)
    Me(uid uint) (*dto.UserResponse, error)
	UpdateMe(uid uint, req dto.UpdateMeRequest) (*dto.UserResponse, error)
	ChangeMyPassword(uid uint, req dto.ChangePasswordRequest) error
	List(q dto.ListUsersQuery) (*dto.PagedResult[dto.UserResponse], error)
	Delete(uid uint, targetID uint) error // อนุญาตเฉพาะ uid==targetID
}
