package routes

import (
    veripkg "github.com/RathaTart/FoodBridge/pkg/verification"
    userpkg "github.com/RathaTart/FoodBridge/pkg/user"
    "github.com/labstack/echo/v4"
    "gorm.io/gorm"
)

func RegisterVerificationRoutes(g *echo.Group, db *gorm.DB) {
    repo := veripkg.NewRepository(db)
    urepo := userpkg.NewRepository(db)
    svc  := veripkg.NewService(repo, urepo)
    ctl  := veripkg.NewController(svc)

    // ผู้ใช้ยื่นคำขอ
    g.POST("/me/verification", ctl.Create)

    // ส่วนแอดมิน (จะมี middleware กันอีกชั้นที่ layer group)
    g.GET("/admin/verifications", ctl.AdminList)
    g.PUT("/admin/verifications/:id/approve", ctl.Approve)
    g.PUT("/admin/verifications/:id/reject", ctl.Reject)
}
