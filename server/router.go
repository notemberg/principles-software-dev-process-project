package server

import (
	"net/http"

	"github.com/labstack/echo/v4"

	"github.com/RathaTart/FoodBridge/app"
	"github.com/RathaTart/FoodBridge/server/routes"
)

func Setup(e *echo.Echo, d app.Deps) {
	useMiddlewares(e)

	// health check
	e.GET("/health", func(c echo.Context) error {
		return c.String(http.StatusOK, "ok")
	})
	e.GET("/healthz", func(c echo.Context) error {
		return c.String(http.StatusOK, "ok")
	})

	v1 := e.Group("/api/v1")

	// register all routers
	routes.RegisterUserRoutes(v1, d.DB)
	routes.RegisterBookingRoutes(v1, d)
	routes.RegisterPostRoutes(v1, d)
	routes.RegisterPostDetailRoutes(v1, d)
	routes.RegisterCommentRoutes(v1, d)
	routes.RegisterLikeRoutes(v1, d)
	routes.RegisterLocationRoutes(v1, d)
	routes.RegisterNotificationRoutes(v1, d)
	routes.RegisterVerificationRoutes(v1, d)
	routes.RegisterHistoryRoutes(v1, d)
}
