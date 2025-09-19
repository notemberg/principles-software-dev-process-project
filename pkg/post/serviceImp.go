package post

import (
	"errors"
	"strings"
	"time"

	"github.com/RathaTart/FoodBridge/dto"
	"github.com/RathaTart/FoodBridge/entities"
)

type serviceImpl struct {
	repo Repository
}

func NewService(dbRepo Repository) Service {
	return &serviceImpl{repo: dbRepo}
}

// ------- helpers -------
func toUnixPtr(t *time.Time) *int64 {
	if t == nil { return nil }
	u := t.Unix()
	return &u
}
func toPostResp(p *entities.Post) *dto.PostResponse {
	return &dto.PostResponse{
		PostID:       p.PostID,
		ProviderID:   p.ProviderID,
		Title:        p.Title,
		Description:  p.Description,
		Type:         string(p.Type),
		Price:        p.Price,
		Quantity:     p.Quantity,
		Status:       string(p.Status),
		Address:      p.Address,
		Lat:          p.Lat, Lng: p.Lng,
		AvailableFrom: toUnixPtr(p.AvailableFrom),
		AvailableTo:   toUnixPtr(p.AvailableTo),
		CreatedAt:    p.CreatedAt.Unix(),
		UpdatedAt:    p.UpdatedAt.Unix(),
	}
}
func toDetailResp(d *entities.PostDetail) *dto.PostDetailResponse {
	return &dto.PostDetailResponse{
		PostDetailID: d.PostDetailID,
		PostID:       d.PostID,
		ItemName:     d.ItemName,
		Qty:          d.Qty,
		Unit:         d.Unit,
		Note:         d.Note,
		ExpireAt:     toUnixPtr(d.ExpireAt),
		CreatedAt:    d.CreatedAt.Unix(),
		UpdatedAt:    d.UpdatedAt.Unix(),
	}
}
func ownerOnly(uid uint, providerID uint) error {
	if uid != providerID {
		return errors.New("forbidden: only owner can modify")
	}
	return nil
}

// ------- Post -------
func (s *serviceImpl) Create(uid uint, req dto.CreatePostRequest) (*dto.PostResponse, error) {
	title := strings.TrimSpace(req.Title)
	if title == "" { return nil, errors.New("title is required") }

	pt := entities.PostType(strings.ToUpper(req.Type))
	switch pt {
	case entities.PostTypeFree, entities.PostTypeDiscount, entities.PostTypeCommunity:
	default:
		return nil, errors.New("invalid post type")
	}
	if pt == entities.PostTypeFree {
		req.Price = nil
	}

	p := &entities.Post{
		ProviderID:   uid,
		Title:        title,
		Description:  strings.TrimSpace(req.Description),
		Type:         pt,
		Price:        req.Price,
		Quantity:     req.Quantity,
		Status:       entities.PostStatusOpen,
		Address:      strings.TrimSpace(req.Address),
		Lat:          req.Lat,
		Lng:          req.Lng,
		AvailableFrom: req.AvailableFrom,
		AvailableTo:   req.AvailableTo,
	}
	if err := s.repo.CreatePost(p); err != nil { return nil, err }
	return toPostResp(p), nil
}

func (s *serviceImpl) Update(uid, postID uint, req dto.UpdatePostRequest) (*dto.PostResponse, error) {
	p, err := s.repo.FindPostByID(postID)
	if err != nil { return nil, err }
	if err := ownerOnly(uid, p.ProviderID); err != nil { return nil, err }

	if req.Title != nil {
		if v := strings.TrimSpace(*req.Title); v != "" { p.Title = v }
	}
	if req.Description != nil { p.Description = strings.TrimSpace(*req.Description) }
	if req.Type != nil {
		pt := entities.PostType(strings.ToUpper(*req.Type))
		switch pt {
		case entities.PostTypeFree, entities.PostTypeDiscount, entities.PostTypeCommunity:
			p.Type = pt
			if pt == entities.PostTypeFree { p.Price = nil }
		default:
			return nil, errors.New("invalid type")
		}
	}
	if req.Price != nil {
		if p.Type == entities.PostTypeFree { p.Price = nil } else { p.Price = req.Price }
	}
	if req.Quantity != nil && *req.Quantity >= 0 { p.Quantity = *req.Quantity }
	if req.Status != nil {
		st := entities.PostStatus(strings.ToUpper(*req.Status))
		switch st {
		case entities.PostStatusOpen, entities.PostStatusClosed:
			p.Status = st
		default:
			return nil, errors.New("invalid status")
		}
	}
	if req.Address != nil { p.Address = strings.TrimSpace(*req.Address) }
	if req.Lat != nil { p.Lat = req.Lat }
	if req.Lng != nil { p.Lng = req.Lng }
	if req.AvailableFrom != nil { p.AvailableFrom = req.AvailableFrom }
	if req.AvailableTo != nil { p.AvailableTo = req.AvailableTo }

	if err := s.repo.UpdatePost(p); err != nil { return nil, err }
	return toPostResp(p), nil
}

func (s *serviceImpl) Delete(uid, postID uint) error {
	p, err := s.repo.FindPostByID(postID)
	if err != nil { return err }
	if err := ownerOnly(uid, p.ProviderID); err != nil { return err }
	return s.repo.DeletePostHard(postID)
}

func (s *serviceImpl) GetByID(uid, postID uint) (*dto.PostResponse, error) {
	p, err := s.repo.FindPostByID(postID)
	if err != nil { return nil, err }
	return toPostResp(p), nil
}

func (s *serviceImpl) List(uid uint, q dto.ListPostsQuery) (*dto.PagedResult[dto.PostResponse], error) {
	rows, total, err := s.repo.ListPosts(q, uid)
	if err != nil { return nil, err }
	out := make([]dto.PostResponse, 0, len(rows))
	for i := range rows { out = append(out, *toPostResp(&rows[i])) }
	if q.Page <= 0 { q.Page = 1 }
	if q.PageSize <= 0 { q.PageSize = 20 }
	if q.PageSize > 100 { q.PageSize = 100 }
	return &dto.PagedResult[dto.PostResponse]{
		Items: out, Total: total, Page: q.Page, PageSize: q.PageSize,
	}, nil
}

// ------- PostDetail -------
func (s *serviceImpl) CreateDetail(uid, postID uint, req dto.CreatePostDetailRequest) (*dto.PostDetailResponse, error) {
	p, err := s.repo.FindPostByID(postID)
	if err != nil { return nil, err }
	if err := ownerOnly(uid, p.ProviderID); err != nil { return nil, err }

	if strings.TrimSpace(req.ItemName) == "" {
		return nil, errors.New("item_name is required")
	}
	d := &entities.PostDetail{
		PostID:   postID,
		ItemName: strings.TrimSpace(req.ItemName),
		Qty:      req.Qty,
		Unit:     strings.TrimSpace(req.Unit),
		Note:     strings.TrimSpace(req.Note),
		ExpireAt: req.ExpireAt,
	}
	if err := s.repo.CreateDetail(d); err != nil { return nil, err }
	return toDetailResp(d), nil
}

func (s *serviceImpl) UpdateDetail(uid, postID, detailID uint, req dto.UpdatePostDetailRequest) (*dto.PostDetailResponse, error) {
	p, err := s.repo.FindPostByID(postID)
	if err != nil { return nil, err }
	if err := ownerOnly(uid, p.ProviderID); err != nil { return nil, err }

	d, err := s.repo.FindDetail(postID, detailID)
	if err != nil { return nil, err }

	if req.ItemName != nil { d.ItemName = strings.TrimSpace(*req.ItemName) }
	if req.Qty != nil { d.Qty = *req.Qty }
	if req.Unit != nil { d.Unit = strings.TrimSpace(*req.Unit) }
	if req.Note != nil { d.Note = strings.TrimSpace(*req.Note) }
	if req.ExpireAt != nil { d.ExpireAt = req.ExpireAt }

	if err := s.repo.UpdateDetail(d); err != nil { return nil, err }
	return toDetailResp(d), nil
}

func (s *serviceImpl) DeleteDetail(uid, postID, detailID uint) error {
	p, err := s.repo.FindPostByID(postID)
	if err != nil { return err }
	if err := ownerOnly(uid, p.ProviderID); err != nil { return err }
	return s.repo.DeleteDetail(postID, detailID)
}

func (s *serviceImpl) ListDetails(uid, postID uint) ([]dto.PostDetailResponse, error) {
	// เปิดให้ดูได้ทุกคน (ปรับ rule ได้)
	dets, err := s.repo.ListDetails(postID)
	if err != nil { return nil, err }
	out := make([]dto.PostDetailResponse, 0, len(dets))
	for i := range dets { out = append(out, *toDetailResp(&dets[i])) }
	return out, nil
}
