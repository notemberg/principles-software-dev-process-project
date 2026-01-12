package report

import "../../../pkg/report/github.com/RathaTart/FoodBridge/dto"

type Service interface {
	Create(uid, postID uint, req dto.CreateReportRequest) (*dto.ReportResponse, error)
	ListForPost(uid, postID uint) ([]dto.ReportResponse, error) // เฉพาะเจ้าของโพสต์
	ListMine(uid uint) ([]dto.ReportResponse, error)
	UpdateStatus(uid, reportID uint, status string) (*dto.ReportResponse, error) // เฉพาะเจ้าของโพสต์
}
