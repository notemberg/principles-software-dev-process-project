package routes

import (
	"github.com/labstack/echo/v4"
	"gorm.io/gorm"

	"github.com/RathaTart/FoodBridge/pkg/booking"
)

func RegisterBookingRoutes(protected *echo.Group, db *gorm.DB) {
	// build repo -> service -> controller
	repo := booking.NewGormRepo(db)
	svc  := booking.NewService(repo, booking.Config{}) // defaults are fine
	ctrl := booking.NewController(svc)

	// mount under /api/v1/bookings
	bookings := protected.Group("/bookings")
	ctrl.Register(bookings)
}
