package routes

import (
	"net/http"

	"github.com/RathaTart/FoodBridge/app"
	"github.com/labstack/echo/v4"
)

func RegisterHistoryRoutes(v1 *echo.Group, d app.Deps) {
	r := v1.Group("/histories")

	r.GET("", func(c echo.Context) error {
		return c.JSON(http.StatusOK, echo.Map{
			"feature": "history_event",
			"items":   []any{},
		})
	})
}
