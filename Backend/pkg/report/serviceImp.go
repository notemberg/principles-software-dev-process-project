package report

import (
	"encoding/json"
	"errors"
	"strings"
	"time"

	"github.com/RathaTart/FoodBridge/dto"
	"github.com/RathaTart/FoodBridge/entities"
	postpkg "github.com/RathaTart/FoodBridge/pkg/post"
	"gorm.io/datatypes"
)

type serviceImpl struct {
	repo     Repository        // ← ใช้อินเทอร์เฟซจาก repository.go
	postRepo postpkg.Repository
}

func NewService(repo Repository, postRepo postpkg.Repository) Service {
	return &serviceImpl{repo: repo, postRepo: postRepo}
}

var allowedTypes = map[string]struct{}{
	"USABILITY": {}, "PRIVACY": {}, "SPAM": {}, "OTHER": {},
}

func normTypes(in []string) ([]string, error) {
	out := make([]string, 0, len(in))
	seen := map[string]bool{}
	for _, s := range in {
		v := strings.ToUpper(strings.TrimSpace(s))
		if v == "" { continue }
		if _, ok := allowedTypes[v]; !ok {
			return nil, errors.New("invalid type: " + v)
		}
		if !seen[v] { seen[v] = true; out = append(out, v) }
	}
	return out, nil
}

func toJSON(ss []string) datatypes.JSON {
	if ss == nil { return datatypes.JSON([]byte("[]")) }
	b, _ := json.Marshal(ss)
	return datatypes.JSON(b)
}
func fromJSON(j datatypes.JSON) []string {
	var out []string
	_ = json.Unmarshal([]byte(j), &out)
	return out
}
func toUnixPtr(t *time.Time) *int64 { if t == nil { return nil }; u := t.Unix(); return &u }

func toResp(m *entities.Report) *dto.ReportResponse {
	return &dto.ReportResponse{
		ReportID:   m.ReportID,
		PostID:     m.PostID,
		ReporterID: m.ReporterID,
		Title:      m.Title,
		Types:      fromJSON(m.Types),
		Detail:     m.Detail,
		Images:     fromJSON(m.Images),
		Status:     string(m.Status),
		CreatedAt:  m.CreatedAt.Unix(),
		UpdatedAt:  m.UpdatedAt.Unix(),
	}
}

func (s *serviceImpl) Create(uid, postID uint, req dto.CreateReportRequest) (*dto.ReportResponse, error) {
	// ต้องมีโพสต์อยู่จริง
	if _, err := s.postRepo.FindPostByID(postID); err != nil { return nil, err }

	title := strings.TrimSpace(req.Title)
	if title == "" { return nil, errors.New("title is required") }

	types, err := normTypes(req.Types)
	if err != nil { return nil, err }

	m := &entities.Report{
		PostID:     postID,
		ReporterID: uid,
		Title:      title,
		Detail:     strings.TrimSpace(req.Detail),
		Types:      toJSON(types),
		Images:     toJSON(req.Images),
		Status:     entities.ReportStatusOpen,
	}
	if err := s.repo.Create(m); err != nil { return nil, err }
	return toResp(m), nil
}

func (s *serviceImpl) ListForPost(uid, postID uint) ([]dto.ReportResponse, error) {
	p, err := s.postRepo.FindPostByID(postID)
	if err != nil { return nil, err }
	if uid != p.ProviderID { return nil, errors.New("forbidden: only post owner can view reports") }

	list, err := s.repo.ListByPost(postID)
	if err != nil { return nil, err }
	out := make([]dto.ReportResponse, 0, len(list))
	for i := range list { out = append(out, *toResp(&list[i])) }
	return out, nil
}

func (s *serviceImpl) ListMine(uid uint) ([]dto.ReportResponse, error) {
	list, err := s.repo.ListByUser(uid)
	if err != nil { return nil, err }
	out := make([]dto.ReportResponse, 0, len(list))
	for i := range list { out = append(out, *toResp(&list[i])) }
	return out, nil
}

func (s *serviceImpl) UpdateStatus(uid, reportID uint, status string) (*dto.ReportResponse, error) {
	m, err := s.repo.FindByID(reportID)
	if err != nil { return nil, err }

	p, err := s.postRepo.FindPostByID(m.PostID)
	if err != nil { return nil, err }
	if uid != p.ProviderID { return nil, errors.New("forbidden: only post owner can update status") }

	up := strings.ToUpper(strings.TrimSpace(status))
	switch entities.ReportStatus(up) {
	case entities.ReportStatusOpen, entities.ReportStatusResolved, entities.ReportStatusRejected:
		m.Status = entities.ReportStatus(up)
	default:
		return nil, errors.New("invalid status")
	}

	if err := s.repo.Update(m); err != nil { return nil, err }
	return toResp(m), nil
}
