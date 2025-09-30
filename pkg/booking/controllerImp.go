package booking

import (
	"net/http"
	"strconv"
	"time"
	"strings"

	"github.com/RathaTart/FoodBridge/dto"
	"github.com/RathaTart/FoodBridge/entities"
	"github.com/labstack/echo/v4"
)

type controller struct{ svc Service }

func NewController(svc Service) Controller { return &controller{svc: svc} }

func (h *controller) Register(g *echo.Group) {
	g.GET("", h.list)
	g.GET("/:id", h.get)
	g.PATCH("/:id", h.patch)           // {status: CANCELLED|COMPLETED}
	g.POST("/:id/qr", h.issueQR)       // body: {"ttl_seconds":600}
	g.POST("/scan", h.scanQR)          // body: {"token":"..."}
}

func (h *controller) RegisterUnderPosts(posts *echo.Group) {
	posts.POST("/:post_id/bookings", h.create)
}

func (h *controller) list(c echo.Context) error {
	var f Filter
	if v := c.QueryParam("post_id"); v != "" {
		id, _ := strconv.ParseInt(v, 10, 64)
		f.PostID = &id
	}
	if v := c.QueryParam("receiver_user_id"); v != "" {
		id, _ := strconv.ParseInt(v, 10, 64)
		f.ReceiverUserID = &id
	}
	if v := c.QueryParam("status"); v != "" {
		s := entities.BookingStatus(v)
		f.Status = &s
	}
	out, err := h.svc.List(c.Request().Context(), f)
	if err != nil {
		return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()})
	}
	return c.JSON(http.StatusOK, dto.FromEntities(out))
}

func (h *controller) get(c echo.Context) error {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error":"bad_id"}) }
	b, err := h.svc.Get(c.Request().Context(), id)
	if err != nil { return c.JSON(http.StatusNotFound, echo.Map{"error":"not_found"}) }
	return c.JSON(http.StatusOK, dto.FromEntity(b))
}

func (h *controller) create(c echo.Context) error {
	postID, err := strconv.ParseInt(c.Param("post_id"), 10, 64)
	if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error":"bad_post_id"}) }

	// Auth: get user_id from context (JWT middleware should set it)
	uidAny := c.Get("user_id")
	userID, ok := uidAny.(int64)
	if !ok || userID == 0 {
		// temporary dev fallback from header X-User-ID
		if v := c.Request().Header.Get("X-User-ID"); v != "" {
			if n, e := strconv.ParseInt(v, 10, 64); e == nil { userID = n }
		}
	}
	if userID == 0 { return c.JSON(http.StatusUnauthorized, echo.Map{"error":"unauthorized"}) }

	b, err := h.svc.Create(c.Request().Context(), postID, userID)
	if err != nil {
    if strings.Contains(err.Error(), "cannot_book_own_post") {
        return c.JSON(http.StatusForbidden, echo.Map{"error": "cannot_book_own_post"})
    }
    if strings.Contains(err.Error(), "no_booking_token_left") {
        return c.JSON(http.StatusBadRequest, echo.Map{"error": "no_booking_token_left"})
    }
    return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()})
}
	return c.JSON(http.StatusCreated, dto.FromEntity(b))
}

func (h *controller) patch(c echo.Context) error {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error":"bad_id"}) }
	var body struct {
		Status string `json:"status"`
	}
	if err := c.Bind(&body); err != nil {
		return c.JSON(http.StatusBadRequest, echo.Map{"error":"bad_body"})
	}
	switch body.Status {
	case "CANCELLED":
		if err := h.svc.Cancel(c.Request().Context(), id); err != nil {
			return c.JSON(http.StatusBadRequest, echo.Map{"error":err.Error()})
		}
	case "COMPLETED":
		if err := h.svc.Complete(c.Request().Context(), id); err != nil {
			return c.JSON(http.StatusBadRequest, echo.Map{"error":err.Error()})
		}
	default:
		return c.JSON(http.StatusBadRequest, echo.Map{"error":"unsupported_status"})
	}
	return c.NoContent(http.StatusNoContent)
}

func (h *controller) issueQR(c echo.Context) error {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error":"bad_id"}) }
	var body struct {
		TTLSeconds int64 `json:"ttl_seconds"`
	}
	_ = c.Bind(&body)
	ttl := time.Duration(body.TTLSeconds) * time.Second
	token, err := h.svc.IssueQR(c.Request().Context(), id, ttl)
	if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()}) }
	return c.JSON(http.StatusOK, echo.Map{"token": token})
}

func (h *controller) scanQR(c echo.Context) error {
	var body struct{ Token string `json:"token"` }
	if err := c.Bind(&body); err != nil || body.Token == "" {
		return c.JSON(http.StatusBadRequest, echo.Map{"error":"bad_body"})
	}
	b, err := h.svc.ScanQR(c.Request().Context(), body.Token)
	if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()}) }
	return c.JSON(http.StatusOK, dto.FromEntity(b))
}
