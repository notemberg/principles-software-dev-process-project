package report

import "github.com/labstack/echo/v4"

type Controller interface {
	Create(c echo.Context) error
	ListForPost(c echo.Context) error
	ListMine(c echo.Context) error
	UpdateStatus(c echo.Context) error
}
