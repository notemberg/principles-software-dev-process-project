package notification

import "github.com/labstack/echo/v4"

type Controller interface {
    Register(g *echo.Group)
}
