package verification

import "github.com/labstack/echo/v4"

type Controller interface {
    Create(c echo.Context) error
    AdminList(c echo.Context) error
    Approve(c echo.Context) error
    Reject(c echo.Context) error
}
