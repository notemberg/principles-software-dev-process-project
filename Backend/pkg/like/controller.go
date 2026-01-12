package like

import "../../../pkg/like/github.com/labstack/echo/v4"

type Controller interface {
	RegisterUnderPosts(posts *echo.Group) // /posts
}
