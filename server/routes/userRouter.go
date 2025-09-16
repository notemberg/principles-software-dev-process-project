// server/routes/userRouter.go
package routes

import (
	userpkg "github.com/RathaTart/FoodBridge/pkg/user"
	"github.com/labstack/echo/v4"
	"gorm.io/gorm"
)

// เหมือนไฟล์ router อื่น ๆ: ใช้ v1 group
func RegisterUserRoutes(v1 *echo.Group, db *gorm.DB) {
	repo := userpkg.NewRepository(db)
	svc  := userpkg.NewService(db, repo)
	ctrl := userpkg.NewController(svc)

	// /api/v1/...  (prefix มาจาก v1)
	v1.POST("/auth/register", ctrl.Register)
	v1.POST("/auth/login",    ctrl.Login)

	v1.GET ("/users/:id",     ctrl.GetByID)
	v1.PUT ("/users/:id",     ctrl.UpdateProfile)
}
