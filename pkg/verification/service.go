package verification

import "github.com/RathaTart/FoodBridge/dto"

type Service interface {
    Create(uid uint, req dto.CreateVerificationRequest) (*dto.VerificationResponse, error)
    ListAdmin(uid uint, status string) ([]dto.VerificationResponse, error)         // admin only
    Approve(uid uint, id uint) (*dto.VerificationResponse, error)                  // admin only
    Reject(uid uint, id uint, note string) (*dto.VerificationResponse, error)      // admin only
}
