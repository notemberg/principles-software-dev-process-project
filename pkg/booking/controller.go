package booking

import "github.com/labstack/echo/v4"

// Controller registers handlers onto subgroups
type Controller interface {
	Register(bookings *echo.Group)           // /bookings
	RegisterUnderPosts(posts *echo.Group)    // /posts/:post_id/bookings
}
