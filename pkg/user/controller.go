package user

import "github.com/labstack/echo/v4"

type Controller interface {
	Register(c echo.Context) error
	Login(c echo.Context) error
	GetByID(c echo.Context) error
	UpdateProfile(c echo.Context) error
}
