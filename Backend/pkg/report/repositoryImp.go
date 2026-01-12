package report

import (
	"github.com/RathaTart/FoodBridge/entities"
	"gorm.io/gorm"
)

type repositoryImpl struct{ db *gorm.DB }

func NewRepository(db *gorm.DB) Repository { return &repositoryImpl{db: db} }

func (r *repositoryImpl) Create(m *entities.Report) error {
	return r.db.Create(m).Error
}

func (r *repositoryImpl) FindByID(id uint) (*entities.Report, error) {
	var m entities.Report
	if err := r.db.First(&m, "report_id = ?", id).Error; err != nil {
		return nil, err
	}
	return &m, nil
}

func (r *repositoryImpl) ListByPost(postID uint) ([]entities.Report, error) {
	var list []entities.Report
	err := r.db.Where("post_id = ?", postID).Order("created_at DESC").Find(&list).Error
	return list, err
}

func (r *repositoryImpl) ListByUser(userID uint) ([]entities.Report, error) {
	var list []entities.Report
	err := r.db.Where("reporter_id = ?", userID).Order("created_at DESC").Find(&list).Error
	return list, err
}

func (r *repositoryImpl) Update(m *entities.Report) error {
	return r.db.Save(m).Error
}
