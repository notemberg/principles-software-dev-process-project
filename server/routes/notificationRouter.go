package routes

import (
    "github.com/labstack/echo/v4"
    "gorm.io/gorm"

    "github.com/RathaTart/FoodBridge/pkg/notification"
)

func RegisterNotificationRoutes(protected *echo.Group, db *gorm.DB) {
    repo := notification.NewRepository(db)
    svc  := notification.NewService(repo)
    ctrl := notification.NewController(svc)

    g := protected.Group("/notifications")
    ctrl.Register(g)
}
