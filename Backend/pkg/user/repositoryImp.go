package user

import (
	"strings"

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

// ===== Read by ID =====
func (r *repositoryImpl) FindByID(id uint) (*entities.User, error) {
	var u entities.User
	if err := r.db.First(&u, "user_id = ?", id).Error; err != nil {
		return nil, err
	}
	return &u, nil
}

// alias ให้เข้ากับ service ที่เรียก GetByID
func (r *repositoryImpl) GetByID(id uint) (*entities.User, error) {
	return r.FindByID(id)
}

// ===== Read by login (phone หรือ email) =====
func (r *repositoryImpl) FindByLogin(login string) (*entities.User, error) {
	lg := strings.TrimSpace(login)
	var u entities.User
	err := r.db.
		Where("phone = ? OR (email IS NOT NULL AND LOWER(email) = LOWER(?))", lg, lg).
		First(&u).Error
	if err != nil {
		return nil, err
	}
	return &u, nil
}

// ===== Exists =====
func (r *repositoryImpl) ExistsByPhone(phone string) (bool, error) {
	p := strings.TrimSpace(phone)
	var count int64
	if err := r.db.Model(&entities.User{}).
		Where("phone = ?", p).
		Count(&count).Error; err != nil {
		return false, err
	}
	return count > 0, nil
}

func (r *repositoryImpl) ExistsByEmail(email string) (bool, error) {
	e := strings.TrimSpace(email)
	var count int64
	if err := r.db.Model(&entities.User{}).
		Where("email IS NOT NULL AND LOWER(email) = LOWER(?)", e).
		Count(&count).Error; err != nil {
		return false, err
	}
	return count > 0, nil
}

// ===== Update =====
func (r *repositoryImpl) Update(u *entities.User) error {
	// Save ทั้ง struct เพื่อไม่ตกหล่นคอลัมน์ใหม่ ๆ
	return r.db.Save(u).Error
}
