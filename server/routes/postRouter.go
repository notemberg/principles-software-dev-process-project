package routes

import (
	postpkg "github.com/RathaTart/FoodBridge/pkg/post"
	"github.com/labstack/echo/v4"
	"gorm.io/gorm"
)

func RegisterPostRoutes(g *echo.Group, db *gorm.DB) {
	repo := postpkg.NewRepository(db)
	svc  := postpkg.NewService(repo)
	ctrl := postpkg.NewController(svc)

	// Post
	g.POST  ("/posts",               ctrl.Create)
	g.GET   ("/posts",               ctrl.List)
	g.GET   ("/posts/:post_id",      ctrl.GetByID)
	g.PUT   ("/posts/:post_id",      ctrl.Update)
	g.DELETE("/posts/:post_id",      ctrl.Delete)

	// PostDetail
	g.POST  ("/posts/:post_id/details",            ctrl.CreateDetail)
	g.GET   ("/posts/:post_id/details",            ctrl.ListDetails)
	g.PUT   ("/posts/:post_id/details/:detail_id", ctrl.UpdateDetail)
	g.DELETE("/posts/:post_id/details/:detail_id", ctrl.DeleteDetail)
}
