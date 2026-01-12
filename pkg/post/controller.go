package post

import "github.com/labstack/echo/v4"

type Controller interface {
	// Post
	Create(c echo.Context) error
	Update(c echo.Context) error
	Delete(c echo.Context) error
	GetByID(c echo.Context) error
	List(c echo.Context) error
	ListByUser(c echo.Context) error

	// PostDetail
	CreateDetail(c echo.Context) error
	UpdateDetail(c echo.Context) error
	DeleteDetail(c echo.Context) error
	ListDetails(c echo.Context) error
}
