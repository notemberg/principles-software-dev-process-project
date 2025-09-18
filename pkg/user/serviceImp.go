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

func (s *serviceImpl) UpdateProfile(id uint, req dto.UpdateProfileRequest) (*dto.UserResponse, error) {
	u, err := s.repo.FindByID(id)
	if err != nil {
		return nil, err
	}

	if req.FullName != nil {
		name := strings.TrimSpace(*req.FullName)
		u.FullName = name
	}
	if req.AvatarURL != nil {
		u.AvatarURL = req.AvatarURL
	}

	if err := s.repo.Update(u); err != nil {
		return nil, err
	}
	return s.toResponse(u), nil
}

// ---------- helpers ----------

func (s *serviceImpl) toResponse(u *entities.User) *dto.UserResponse {
	return &dto.UserResponse{
		UserID:     u.UserID,
		Phone:      u.Phone,
		Email:      u.Email,
		FullName:   u.FullName,
		AvatarURL:  u.AvatarURL,
		IsVerified: u.IsVerified,
	}
}

func isNotFound(err error) bool {
	return strings.Contains(strings.ToLower(err.Error()), strings.ToLower(logger.ErrRecordNotFound.Error()))
}
