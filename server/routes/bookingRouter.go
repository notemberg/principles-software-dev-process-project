package routes

import (
	"github.com/labstack/echo/v4"
	"gorm.io/gorm"

	"github.com/RathaTart/FoodBridge/pkg/booking"
)

func RegisterBookingRoutes(protected *echo.Group, db *gorm.DB) {
	repo := booking.NewGormRepo(db)
	svc  := booking.NewService(repo, booking.Config{}) // set secrets in bootstrap
	ctrl := booking.NewController(svc)

	bookings := protected.Group("/bookings")
	ctrl.Register(bookings)

	posts := protected.Group("/posts")
	ctrl.RegisterUnderPosts(posts)
}
