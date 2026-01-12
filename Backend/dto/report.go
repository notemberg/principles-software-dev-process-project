package dto

type CreateReportRequest struct {
	Title  string   `json:"title"`            // ปัญหาที่เกิด (หัวข้อ)
	Types  []string `json:"types"`            // ["USABILITY","PRIVACY","SPAM","OTHER"]
	Detail string   `json:"detail"`           // รายละเอียด
	Images []string `json:"images"`           // URL/Path รูป
}

type ReportResponse struct {
	ReportID   uint     `json:"report_id"`
	PostID     uint     `json:"post_id"`
	ReporterID uint     `json:"reporter_id"`
	Title      string   `json:"title"`
	Types      []string `json:"types"`
	Detail     string   `json:"detail"`
	Images     []string `json:"images"`
	Status     string   `json:"status"`
	CreatedAt  int64    `json:"created_at"`
	UpdatedAt  int64    `json:"updated_at"`
}

type UpdateReportStatusRequest struct {
	Status string `json:"status"` // OPEN | RESOLVED | REJECTED
}
