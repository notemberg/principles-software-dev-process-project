package user

import (
	"github.com/RathaTart/FoodBridge/entities"
	"gorm.io/gorm"
)

type repositoryImpl struct {
	db *gorm.DB
}

func NewRepository(db *gorm.DB) Repository {
	return &repositoryImpl{db: db}
}

func (r *repositoryImpl) Create(u *entities.User) error {
	return r.db.Create(u).Error
}

func (r *repositoryImpl) FindByID(id uint) (*entities.User, error) {
	var u entities.User
	if err := r.db.First(&u, "user_id = ?", id).Error; err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *repositoryImpl) FindByLogin(login string) (*entities.User, error) {
	var u entities.User
	err := r.db.
		Where("phone = ? OR LOWER(email) = LOWER(?)", login, login).
		First(&u).Error
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *repositoryImpl) ExistsByPhone(phone string) (bool, error) {
	var count int64
	if err := r.db.Model(&entities.User{}).Where("phone = ?", phone).Count(&count).Error; err != nil {
		return false, err
	}
	return count > 0, nil
}

func (r *repositoryImpl) ExistsByEmail(email string) (bool, error) {
	var count int64
	if err := r.db.Model(&entities.User{}).Where("LOWER(email) = LOWER(?)", email).Count(&count).Error; err != nil {
		return false, err
	}
	return count > 0, nil
}

func (r *repositoryImpl) Update(u *entities.User) error {
	return r.db.Save(u).Error
}
