package dto

type CreateVerificationRequest struct {
    IDCardImageURL string `json:"idcard_image_url"` // URL ที่อัปโหลดรูปไว้ (backend เก็บเป็นสตริง)
}

type VerificationResponse struct {
    VerificationID uint   `json:"verification_id"`
    UserID         uint   `json:"user_id"`
    AccountName    string `json:"account_name"` // phone หรือ email แสดงในลิสต์ admin ได้
    FullName       string `json:"full_name"`
    IDCardImageURL string `json:"idcard_image_url"`
    Status         string `json:"status"`
    Note           string `json:"note,omitempty"`
    ReviewedBy     *uint  `json:"reviewed_by,omitempty"`
    CreatedAt      int64  `json:"created_at"`
    UpdatedAt      int64  `json:"updated_at"`
}

type ListVerificationQuery struct {
    Status string `query:"status"` // PENDING|APPROVED|REJECTED (default=PENDING)
}

type RejectRequest struct {
    Note string `json:"note"`
}
