package booking

import "../../../pkg/booking/github.com/labstack/echo/v4"

type Controller interface {
	Register(bookings *echo.Group)        // /bookings
	RegisterUnderPosts(posts *echo.Group) // /posts/:post_id/bookings
}
