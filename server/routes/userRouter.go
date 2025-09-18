// server/routes/userRouter.go
package routes

import (
	userpkg "github.com/RathaTart/FoodBridge/pkg/user"
	"github.com/labstack/echo/v4"
	"gorm.io/gorm"
)

func RegisterUserRoutes(g *echo.Group, db *gorm.DB) {
	repo := userpkg.NewRepository(db)
	svc := userpkg.NewService(db, repo)
	ctrl := userpkg.NewController(svc)

	// public
	g.POST("/auth/register", ctrl.Register)
	g.POST("/auth/login", ctrl.Login)
}

// ===== Protected (ต้องใช้ token) =====
func RegisterUserProtectedRoutes(g *echo.Group, db *gorm.DB) {
	repo := userpkg.NewRepository(db)
	svc := userpkg.NewService(db, repo)
	ctrl := userpkg.NewController(svc)

	// ตัวเอง
	g.GET("/me", ctrl.Me)
	g.PUT("/me", ctrl.UpdateMe)
	g.PUT("/me/password", ctrl.ChangeMyPassword)

	// ผู้ใช้อื่น
	g.GET("/users", ctrl.List) 			// ?page=&page_size=&q=&verified=&sort=
	g.GET("/users/:id", ctrl.GetByID)
	g.DELETE("/users/:id", ctrl.Delete) // ลบได้เฉพาะ owner (uid==:id)
}
