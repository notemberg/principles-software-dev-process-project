package verification

import (
    "errors"
    "strings"
    "time"

    "github.com/RathaTart/FoodBridge/dto"
    "github.com/RathaTart/FoodBridge/entities"
    userpkg "github.com/RathaTart/FoodBridge/pkg/user"
)

type serviceImpl struct {
    repo    Repository
    userRepo userpkg.Repository
}

func NewService(repo Repository, userRepo userpkg.Repository) Service {
    return &serviceImpl{repo: repo, userRepo: userRepo}
}

func toResp(v *entities.Verification, u *entities.User) *dto.VerificationResponse {
    acct := u.Phone
    if u.Email != nil && *u.Email != "" {
        acct = *u.Email
    }
    return &dto.VerificationResponse{
        VerificationID: v.VerificationID,
        UserID:         v.UserID,
        AccountName:    acct,
        FullName:       u.FullName,
        IDCardImageURL: v.IDCardImageURL,
        Status:         string(v.Status),
        Note:           v.Note,
        ReviewedBy:     v.ReviewedBy,
        CreatedAt:      v.CreatedAt.Unix(),
        UpdatedAt:      v.UpdatedAt.Unix(),
    }
}

func (s *serviceImpl) Create(uid uint, req dto.CreateVerificationRequest) (*dto.VerificationResponse, error) {
    url := strings.TrimSpace(req.IDCardImageURL)
    if url == "" {
        return nil, errors.New("idcard_image_url is required")
    }

    // ผู้ใช้ต้องมีอยู่
    u, err := s.userRepo.FindByID(uid)
    if err != nil { return nil, err }

    m := &entities.Verification{
        UserID:        uid,
        IDCardImageURL: url,
        Status:        entities.VerificationPending,
    }
    if err := s.repo.Create(m); err != nil { return nil, err }
    return toResp(m, u), nil
}

func (s *serviceImpl) ListAdmin(uid uint, status string) ([]dto.VerificationResponse, error) {
    // ตรวจว่าเป็น admin ที่ layer middleware แล้ว แต่กันอีกชั้น:
    u, err := s.userRepo.FindByID(uid)
    if err != nil { return nil, err }
    if strings.ToUpper(u.Role) != "ADMIN" {
        return nil, errors.New("forbidden: admin only")
    }

    var st *entities.VerificationStatus
    if status != "" {
        tmp := entities.VerificationStatus(strings.ToUpper(status))
        st = &tmp
    }
    list, err := s.repo.List(st)
    if err != nil { return nil, err }

    // join user (ทีละรายการ—พอสำหรับงาน admin list)
    out := make([]dto.VerificationResponse, 0, len(list))
    for i := range list {
        uu, _ := s.userRepo.FindByID(list[i].UserID)
        if uu == nil { continue }
        out = append(out, *toResp(&list[i], uu))
    }
    return out, nil
}

func (s *serviceImpl) approveRejectCommon(adminID, id uint, approve bool, note string) (*dto.VerificationResponse, error) {
    v, err := s.repo.FindByID(id)
    if err != nil { return nil, err }

    admin, err := s.userRepo.FindByID(adminID)
    if err != nil { return nil, err }
    if strings.ToUpper(admin.Role) != "ADMIN" {
        return nil, errors.New("forbidden: admin only")
    }

    now := time.Now()
    v.ReviewedBy = &adminID
    v.ReviewedAt = &now
    if approve {
        v.Status = entities.VerificationApproved
        v.Note = ""
        // set user.is_verified = true
        u, err := s.userRepo.FindByID(v.UserID)
        if err != nil { return nil, err }
        u.IsVerified = true
        if err := s.userRepo.Update(u); err != nil { return nil, err }
    } else {
        v.Status = entities.VerificationRejected
        v.Note = strings.TrimSpace(note)
    }

    if err := s.repo.Update(v); err != nil { return nil, err }
    u, _ := s.userRepo.FindByID(v.UserID)
    return toResp(v, u), nil
}

func (s *serviceImpl) Approve(uid, id uint) (*dto.VerificationResponse, error) {
    return s.approveRejectCommon(uid, id, true, "")
}

func (s *serviceImpl) Reject(uid, id uint, note string) (*dto.VerificationResponse, error) {
    return s.approveRejectCommon(uid, id, false, note)
}
