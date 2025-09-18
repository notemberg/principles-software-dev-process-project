// pkg/user/serviceImp.go
package user

import (
	"errors"
	"strings"
	"time"

	"github.com/golang-jwt/jwt"
	"github.com/RathaTart/FoodBridge/config"
	"github.com/RathaTart/FoodBridge/dto"
	"github.com/RathaTart/FoodBridge/entities"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

type serviceImpl struct {
	repo Repository
	db   *gorm.DB
}

func NewService(db *gorm.DB, repo Repository) Service {
	return &serviceImpl{db: db, repo: repo}
}

// ---------- IMPLEMENTATION ----------

func (s *serviceImpl) Register(req dto.RegisterRequest) (*dto.UserResponse, error) {
	req.Phone = strings.TrimSpace(req.Phone)
	req.FullName = strings.TrimSpace(req.FullName)
	if req.Email != nil {
		e := strings.TrimSpace(*req.Email)
		req.Email = &e
	}

	// validate
	if req.Phone == "" || len(req.Password) < 8 || req.FullName == "" {
		return nil, errors.New("invalid input")
	}

	// duplicate check
	if ok, err := s.repo.ExistsByPhone(req.Phone); err != nil {
		return nil, err
	} else if ok {
		return nil, errors.New("phone already used")
	}
	if req.Email != nil && *req.Email != "" {
		if ok, err := s.repo.ExistsByEmail(*req.Email); err != nil {
			return nil, err
		} else if ok {
			return nil, errors.New("email already used")
		}
	}

	// hash password
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	u := &entities.User{
		Phone:        req.Phone,
		Email:        req.Email,
		PasswordHash: string(hash),
		FullName:     req.FullName,
		IsVerified:   false,
	}

	if err := s.repo.Create(u); err != nil {
		return nil, err
	}
	return s.toResponse(u), nil
}

func (s *serviceImpl) Login(req dto.LoginRequest) (*dto.AuthResponse, error) {
	login := strings.TrimSpace(req.Login)
	u, err := s.repo.FindByLogin(login)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) || isNotFound(err) {
			return nil, errors.New("user not found")
		}
		return nil, err
	}
	if bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(req.Password)) != nil {
		return nil, errors.New("invalid credential")
	}

	// อัปเดต last login
	now := time.Now()
	u.LastLoginAt = &now
	if err := s.repo.Update(u); err != nil {
		// ไม่ critical ถึงขั้นต้อง fail login — จะข้ามได้ถ้าต้องการ
	}

	// ===== สร้าง JWT =====
	cfg := config.Load()
	claims := jwt.MapClaims{
		"uid": u.UserID,          // ใช้ uid แทน
		"exp": time.Now().Add(72 * time.Hour).Unix(), // อายุ 3 วัน
		// "role": "RECEIVER",     // ถ้าอนาคตมี role ใส่ตรงนี้ได้
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokStr, err := token.SignedString([]byte(cfg.JWTSecret))
	if err != nil {
		return nil, errors.New("failed to sign token")
	}

	return &dto.AuthResponse{
		Token: tokStr,
		User:  s.toResponse(u),
	}, nil
}

func (s *serviceImpl) GetByID(id uint) (*dto.UserResponse, error) {
	u, err := s.repo.FindByID(id)
	if err != nil {
		return nil, err
	}
	return s.toResponse(u), nil
}

func (s *serviceImpl) Me(uid uint) (*dto.UserResponse, error) {
	u, err := s.repo.FindByID(uid)
	if err != nil { return nil, err }
	return s.toResponse(u), nil
}

func (s *serviceImpl) UpdateMe(uid uint, req dto.UpdateMeRequest) (*dto.UserResponse, error) {
	u, err := s.repo.FindByID(uid)
	if err != nil { return nil, err }

	if req.FullName != nil {
		name := strings.TrimSpace(*req.FullName)
		if name != "" { u.FullName = name }
	}
	if req.Email != nil {
		e := strings.TrimSpace(*req.Email)
		if e == "" { u.Email = nil } else { u.Email = &e }
	}
	if req.AvatarURL != nil {
		av := strings.TrimSpace(*req.AvatarURL)
		if av == "" { u.AvatarURL = nil } else { u.AvatarURL = &av }
	}

	if err := s.repo.Update(u); err != nil {
		return nil, err
	}
	return s.toResponse(u), nil
}

func (s *serviceImpl) ChangeMyPassword(uid uint, req dto.ChangePasswordRequest) error {
	if len(req.NewPassword) < 8 {
		return errors.New("new password too short (min 8)")
	}
	u, err := s.repo.FindByID(uid)
	if err != nil { return err }

	// ตรวจรหัสเดิม
	if bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(req.OldPassword)) != nil {
		return errors.New("old password incorrect")
	}
	// hash ใหม่
	hash, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
	if err != nil { return err }
	u.PasswordHash = string(hash)

	return s.repo.Update(u)
}

func (s *serviceImpl) List(q dto.ListUsersQuery) (*dto.PagedResult[dto.UserResponse], error) {
	if q.Page <= 0 { q.Page = 1 }
	if q.PageSize <= 0 { q.PageSize = 20 }
	if q.PageSize > 100 { q.PageSize = 100 }

	tx := s.db.Model(&entities.User{})

	// filter คำค้น
	if strings.TrimSpace(q.Q) != "" {
		like := "%" + strings.TrimSpace(q.Q) + "%"
		tx = tx.Where(
			s.db.Where("full_name ILIKE ?", like).
				Or("phone ILIKE ?", like).
				Or("email ILIKE ?", like),
		)
	}
	// filter verified
	if q.Verified != nil {
		tx = tx.Where("is_verified = ?", *q.Verified)
	}
	// sort
	switch q.Sort {
	case "created_at":
		tx = tx.Order("created_at ASC")
	case "-created_at", "":
		tx = tx.Order("created_at DESC")
	case "full_name":
		tx = tx.Order("full_name ASC")
	case "-full_name":
		tx = tx.Order("full_name DESC")
	default:
		tx = tx.Order("created_at DESC")
	}

	// count
	var total int64
	if err := tx.Count(&total).Error; err != nil { return nil, err }

	// page
	var users []entities.User
	if err := tx.
		Limit(q.PageSize).
		Offset((q.Page-1)*q.PageSize).
		Find(&users).Error; err != nil {
		return nil, err
	}

	out := make([]dto.UserResponse, 0, len(users))
	for i := range users {
		out = append(out, *s.toResponse(&users[i]))
	}
	return &dto.PagedResult[dto.UserResponse]{
		Items:    out,
		Total:    total,
		Page:     q.Page,
		PageSize: q.PageSize,
	}, nil
}

func (s *serviceImpl) Delete(uid uint, targetID uint) error {
	if uid != targetID {
		return errors.New("forbidden: can only delete yourself")
	}
	// ใช้ Unscoped().Delete ถ้าต้องการ hard delete จริง ๆ
	return s.db.Transaction(func(tx *gorm.DB) error {
		// ลบด้วย primary key
		if err := tx.Unscoped().Where("user_id = ?", targetID).
			Delete(&entities.User{}).Error; err != nil {
			return err
		}
		// ถ้ามีตารางลูก/foreign key อื่น ๆ ให้จัดการด้วย (ON DELETE CASCADE หรือ manual)
		return nil
	})
}

// ---------- helpers ----------
func toUnixPtr(t *time.Time) *int64 {
	if t == nil { return nil }
	u := t.Unix()
	return &u
}

func (s *serviceImpl) toResponse(u *entities.User) *dto.UserResponse {
	return &dto.UserResponse{
		UserID:      u.UserID,
		Phone:       u.Phone,
		Email:       u.Email,
		FullName:    u.FullName,
		AvatarURL:   u.AvatarURL,
		IsVerified:  u.IsVerified,
		CreatedAt:   u.CreatedAt.Unix(),
		UpdatedAt:   u.UpdatedAt.Unix(),
		LastLoginAt: toUnixPtr(u.LastLoginAt),
	}
}

func isNotFound(err error) bool {
	return strings.Contains(strings.ToLower(err.Error()), strings.ToLower(logger.ErrRecordNotFound.Error()))
}
