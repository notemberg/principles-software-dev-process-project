package verification

import "github.com/RathaTart/FoodBridge/entities"

type Repository interface {
    Create(v *entities.Verification) error
    FindByID(id uint) (*entities.Verification, error)
    List(status *entities.VerificationStatus) ([]entities.Verification, error)
    Update(v *entities.Verification) error
}
