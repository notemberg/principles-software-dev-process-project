package verification

import (
    "github.com/RathaTart/FoodBridge/entities"
    "gorm.io/gorm"
)

type repositoryImpl struct{ db *gorm.DB }

func NewRepository(db *gorm.DB) Repository { return &repositoryImpl{db: db} }

func (r *repositoryImpl) Create(v *entities.Verification) error {
    return r.db.Create(v).Error
}

func (r *repositoryImpl) FindByID(id uint) (*entities.Verification, error) {
    var m entities.Verification
    if err := r.db.First(&m, "verification_id = ?", id).Error; err != nil {
        return nil, err
    }
    return &m, nil
}

func (r *repositoryImpl) List(status *entities.VerificationStatus) ([]entities.Verification, error) {
    tx := r.db.Model(&entities.Verification{})
    if status != nil && *status != "" {
        tx = tx.Where("status = ?", *status)
    }
    var list []entities.Verification
    if err := tx.Order("created_at DESC").Find(&list).Error; err != nil {
        return nil, err
    }
    return list, nil
}

func (r *repositoryImpl) Update(v *entities.Verification) error {
    return r.db.Save(v).Error
}
