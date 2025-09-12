package routes

import (
	"net/http"

	"github.com/labstack/echo/v4"
	"github.com/RathaTart/FoodBridge/app"
)

func RegisterVerificationRoutes(v1 *echo.Group, d app.Deps) {
	r := v1.Group("/verifications")

	r.GET("", func(c echo.Context) error {
		return c.JSON(http.StatusOK, echo.Map{
			"feature": "identity_verification",
			"items":   []any{},
		})
	})
}
