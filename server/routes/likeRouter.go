package routes

import (
	"net/http"

	"github.com/labstack/echo/v4"
	"github.com/RathaTart/FoodBridge/app"
)

func RegisterLikeRoutes(v1 *echo.Group, d app.Deps) {
	r := v1.Group("/likes")

	r.GET("", func(c echo.Context) error {
		return c.JSON(http.StatusOK, echo.Map{
			"feature": "like",
			"items":   []any{},
		})
	})
}
