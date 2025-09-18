package server

import (
	"net/http"

	"github.com/labstack/echo/v4"

	"github.com/RathaTart/FoodBridge/app"
	"github.com/RathaTart/FoodBridge/server/routes"
)

func Setup(e *echo.Echo, d app.Deps) {
	useMiddlewares(e)

	// ===== public =====
	e.GET("/health", func(c echo.Context) error {
		return c.JSON(http.StatusOK, echo.Map{"status": "ok"})
	})

	// กลุ่ม v1 สำหรับ public auth
	v1Public := e.Group("")
	routes.RegisterUserRoutes(v1Public, d.DB) // มี /auth/login, /auth/register

	// ===== protected =====
	v1 := e.Group("", AuthMiddleware())

	// เรียกใช้ routers อื่น ๆ ใต้ v1 (protected)
	routes.RegisterBookingRoutes(v1, d)
	routes.RegisterPostRoutes(v1, d)
	routes.RegisterPostDetailRoutes(v1, d)
	routes.RegisterCommentRoutes(v1, d)
	routes.RegisterLikeRoutes(v1, d)
	routes.RegisterLocationRoutes(v1, d)
	routes.RegisterNotificationRoutes(v1, d)
	routes.RegisterVerificationRoutes(v1, d)
	routes.RegisterHistoryRoutes(v1, d)
	routes.RegisterUserProtectedRoutes(v1, d.DB)

	for _, r := range e.Routes() {
    e.Logger.Infof("%s  %s  -> %s", r.Method, r.Path, r.Name)
 	}

}
