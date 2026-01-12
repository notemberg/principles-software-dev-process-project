package routes

import (
	"github.com/labstack/echo/v4"
	"gorm.io/gorm"

	"github.com/RathaTart/FoodBridge/pkg/booking"
	"github.com/RathaTart/FoodBridge/pkg/notification"
	"github.com/RathaTart/FoodBridge/server/bootstrap"
)

func RegisterBookingRoutes(protected *echo.Group, db *gorm.DB) {
	repo := booking.NewGormRepo(db)

	// Notification publisher
	notifRepo := notification.NewRepository(db)
	pub := notification.NewPublisher(notifRepo)

	// Pass pub into the service
	svc := booking.NewService(repo, bootstrap.BookingConfig(), pub)
	ctrl := booking.NewController(svc)

	bookings := protected.Group("/bookings")
	ctrl.Register(bookings)

	posts := protected.Group("/posts")
	ctrl.RegisterUnderPosts(posts)
}
