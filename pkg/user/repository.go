package user

import "github.com/RathaTart/FoodBridge/entities"

type Repository interface {
	Create(u *entities.User) error
	FindByID(id uint) (*entities.User, error)
	GetByID(id uint) (*entities.User, error)
	FindByLogin(login string) (*entities.User, error) // phone หรือ email
	ExistsByPhone(phone string) (bool, error)
	ExistsByEmail(email string) (bool, error)
	Update(u *entities.User) error
}
