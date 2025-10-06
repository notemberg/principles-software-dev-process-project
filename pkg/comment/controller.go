package comment

import "github.com/labstack/echo/v4"

type Controller interface {
	RegisterUnderPosts(posts *echo.Group) // POST/GET under /posts
	RegisterTopLevel(g *echo.Group)       // PATCH/DELETE under /comments
}
