package routes

import (
	postpkg "github.com/RathaTart/FoodBridge/pkg/post"
	"github.com/RathaTart/FoodBridge/pkg/booking"
	"github.com/RathaTart/FoodBridge/pkg/like"
	"github.com/RathaTart/FoodBridge/pkg/notification"
	"github.com/labstack/echo/v4"
	"gorm.io/gorm"
)

func RegisterPostRoutes(g *echo.Group, db *gorm.DB) {
	// Post
	repo := postpkg.NewRepository(db)
	svc  := postpkg.NewService(repo)
	ctrl := postpkg.NewController(svc)

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

	// Booking under /posts
	posts := g.Group("/posts")
	bRepo := booking.NewGormRepo(db)
	
	// inject notification publisher for these booking routes too
	notifRepo := notification.NewRepository(db)
	pub := notification.NewPublisher(notifRepo)

	bSvc  := booking.NewService(bRepo, booking.Config{}, pub)
	bCtrl := booking.NewController(bSvc)
	bCtrl.RegisterUnderPosts(posts)

	// Likes under /posts
	lRepo := like.NewRepository(db)
	lSvc  := like.NewService(db, lRepo)
	lCtrl := like.NewController(lSvc)
	lCtrl.RegisterUnderPosts(posts)
}
