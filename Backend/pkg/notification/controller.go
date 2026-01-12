package notification

import "../../../pkg/notification/github.com/labstack/echo/v4"

type Controller interface {
    Register(g *echo.Group)
}
