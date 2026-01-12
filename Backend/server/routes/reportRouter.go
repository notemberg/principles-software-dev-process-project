package routes

import (
	reportpkg "github.com/RathaTart/FoodBridge/pkg/report"
	postpkg "github.com/RathaTart/FoodBridge/pkg/post"
	"github.com/labstack/echo/v4"
	"gorm.io/gorm"
)

// ให้เรียกใช้งานจาก "protected group" (มี AuthMiddleware แล้ว)
func RegisterReportRoutes(g *echo.Group, db *gorm.DB) {
	repRepo := reportpkg.NewRepository(db)
	postRepo := postpkg.NewRepository(db)
	svc     := reportpkg.NewService(repRepo, postRepo)
	ctrl    := reportpkg.NewController(svc)

	// สร้างรายงานใต้โพสต์
	g.POST("/posts/:post_id/reports", ctrl.Create)

	// เจ้าของโพสต์ดูรายงานทั้งหมดของโพสต์
	g.GET("/posts/:post_id/reports", ctrl.ListForPost)

	// รายงานของฉันทั้งหมด
	g.GET("/me/reports", ctrl.ListMine)

	// เจ้าของโพสต์อัปเดตสถานะรายงาน
	g.PUT("/reports/:report_id/status", ctrl.UpdateStatus)
}
