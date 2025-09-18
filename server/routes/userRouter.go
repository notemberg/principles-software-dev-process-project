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

func RegisterUserProtectedRoutes(g *echo.Group, db *gorm.DB) {
	repo := userpkg.NewRepository(db)
	svc := userpkg.NewService(db, repo)
	ctrl := userpkg.NewController(svc)

	// protected
	g.GET("/users/:id", ctrl.GetByID)
	g.PUT("/users/:id", ctrl.UpdateProfile)
}
