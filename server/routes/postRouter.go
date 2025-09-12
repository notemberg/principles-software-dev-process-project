package routes

import (
	"net/http"

	"github.com/labstack/echo/v4"
	"github.com/RathaTart/FoodBridge/app"
)

func RegisterPostRoutes(v1 *echo.Group, d app.Deps) {
	r := v1.Group("/posts")

	r.GET("", func(c echo.Context) error {
		return c.JSON(http.StatusOK, echo.Map{
			"feature": "post",
			"items":   []any{},
		})
	})
}
