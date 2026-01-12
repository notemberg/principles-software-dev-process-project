package user

import "../../../pkg/user/github.com/labstack/echo/v4"

type Controller interface {
	Register(c echo.Context) error
	Login(c echo.Context) error
	GetByID(c echo.Context) error
	Me(c echo.Context) error
	UpdateMe(c echo.Context) error
	ChangeMyPassword(c echo.Context) error
	List(c echo.Context) error
	Delete(c echo.Context) error
	GetMyShareLink(c echo.Context) error
	GetShareLinkByID(c echo.Context) error
}
