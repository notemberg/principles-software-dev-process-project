package report

import "github.com/RathaTart/FoodBridge/entities"

type Repository interface {
	Create(m *entities.Report) error
	FindByID(id uint) (*entities.Report, error)
	ListByPost(postID uint) ([]entities.Report, error)
	ListByUser(userID uint) ([]entities.Report, error)
	Update(m *entities.Report) error
}
