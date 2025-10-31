package booking

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/RathaTart/FoodBridge/dto"
	"github.com/labstack/echo/v4"
)

/* ======================== helpers ======================== */

// uidFromCtx: ดึง uid จาก JWT ที่ AuthMiddleware ใส่ไว้ใน context
func uidFromCtx(c echo.Context) (int64, error) {
	switch v := c.Get("uid").(type) {
	case int64:
		return v, nil
	case int:
		return int64(v), nil
	case uint:
		return int64(v), nil
	case uint64:
		return int64(v), nil
	case float64:
		return int64(v), nil
	case string:
		n, err := strconv.ParseInt(v, 10, 64)
		if err != nil {
			return 0, echo.NewHTTPError(http.StatusUnauthorized, "unauthorized")
		}
		return n, nil
	default:
		return 0, echo.NewHTTPError(http.StatusUnauthorized, "unauthorized")
	}
}

/* ======================== controller ======================== */

type controller struct{ svc Service }

func NewController(svc Service) Controller { return &controller{svc: svc} }

func (h *controller) Register(g *echo.Group) {
	g.GET("", h.list)
	g.GET("/:id", h.get)
	g.PATCH("/:id", h.patch)           // {status: CANCELLED|COMPLETED}
	g.POST("/:id/qr", h.issueQR)       // body: {"ttl_seconds":600}
	g.POST("/scan", h.scanQR)          // body: {"token":"..."}
	g.GET("/daily-limit", h.dailyLimit)
}

func (h *controller) RegisterUnderPosts(posts *echo.Group) {
	posts.POST("/:post_id/bookings", h.create)
}

/* ======================== handlers ======================== */

// GET /bookings
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
	// รองรับหลายสถานะ (CSV)
	if v := c.QueryParam("status"); v != "" {
		parts := strings.Split(v, ",")
		for i := range parts {
			parts[i] = strings.TrimSpace(parts[i])
		}
		f.Statuses = parts
	}

	out, err := h.svc.List(c.Request().Context(), f)
	if err != nil {
		return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()})
	}
	return c.JSON(http.StatusOK, dto.FromEntities(out))
}

// GET /bookings/:id
func (h *controller) get(c echo.Context) error {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		return c.JSON(http.StatusBadRequest, echo.Map{"error": "bad_id"})
	}
	b, err := h.svc.Get(c.Request().Context(), id)
	if err != nil {
		return c.JSON(http.StatusNotFound, echo.Map{"error": "not_found"})
	}
	return c.JSON(http.StatusOK, dto.FromEntity(b))
}

// POST /posts/:post_id/bookings
func (h *controller) create(c echo.Context) error {
	postID, err := strconv.ParseInt(c.Param("post_id"), 10, 64)
	if err != nil {
		return c.JSON(http.StatusBadRequest, echo.Map{"error": "bad_post_id"})
	}

	// ✅ ดึง uid จาก JWT (ไม่ใช้ X-User-ID โดยปกติ)
	uid, err := uidFromCtx(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, echo.Map{"error": "unauthorized"})
	}

	// (ตัวเลือก) อนุญาต ADMIN override ด้วย X-User-ID สำหรับทดสอบเท่านั้น
	if x := strings.TrimSpace(c.Request().Header.Get("X-User-ID")); x != "" {
		if role, _ := c.Get("role").(string); strings.EqualFold(role, "ADMIN") {
			if n, e := strconv.ParseInt(x, 10, 64); e == nil && n > 0 {
				uid = n
			}
		}
	}
	uid, err := uidFromCtx(c)
	if err != nil { return err } // returns 401 with "uid missing" etc.
	userID := int64(uid)

	b, err := h.svc.Create(c.Request().Context(), postID, uid)
	if err != nil {
		if strings.Contains(err.Error(), "cannot_book_own_post") {
			return c.JSON(http.StatusForbidden, echo.Map{"error": "cannot_book_own_post"})
		}
		if strings.Contains(err.Error(), "no_booking_token_left") {
			return c.JSON(http.StatusBadRequest, echo.Map{"error": "no_booking_token_left"})
		}
		return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()})
	}
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

// PATCH /bookings/:id
func (h *controller) patch(c echo.Context) error {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		return c.JSON(http.StatusBadRequest, echo.Map{"error": "bad_id"})
	}
	var body struct {
		Status string `json:"status"`
	}
	if err := c.Bind(&body); err != nil {
		return c.JSON(http.StatusBadRequest, echo.Map{"error": "bad_body"})
	}
	switch body.Status {
	case "CANCELLED":
		if err := h.svc.Cancel(c.Request().Context(), id); err != nil {
			return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()})
		}
	case "COMPLETED":
		if err := h.svc.Complete(c.Request().Context(), id); err != nil {
			return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()})
		}
	default:
		return c.JSON(http.StatusBadRequest, echo.Map{"error": "unsupported_status"})
	}
	return c.NoContent(http.StatusNoContent)
}

// POST /bookings/:id/qr
func (h *controller) issueQR(c echo.Context) error {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		return c.JSON(http.StatusBadRequest, echo.Map{"error": "bad_id"})
	}
	var body struct {
		TTLSeconds int64 `json:"ttl_seconds"`
	}
	_ = c.Bind(&body)
	ttl := time.Duration(body.TTLSeconds) * time.Second
	token, err := h.svc.IssueQR(c.Request().Context(), id, ttl)
	if err != nil {
		return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()})
	}
	return c.JSON(http.StatusOK, echo.Map{"token": token})
}

// POST /bookings/scan
func (h *controller) scanQR(c echo.Context) error {
	var body struct{ Token string `json:"token"` }
	if err := c.Bind(&body); err != nil || body.Token == "" {
		return c.JSON(http.StatusBadRequest, echo.Map{"error": "bad_body"})
	}
	b, err := h.svc.ScanQR(c.Request().Context(), body.Token)
	if err != nil {
		return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()})
	}
	return c.JSON(http.StatusOK, dto.FromEntity(b))
}

func (h *controller) dailyLimit(c echo.Context) error {
	uid, err := uidFromCtx(c)
	if err != nil { return err } // 401
	limit, used, left, start, end, e := h.svc.DailyLimitLeft(c.Request().Context(), int64(uid), time.Now())
	if e != nil {
		return c.JSON(http.StatusInternalServerError, echo.Map{"error": e.Error()})
	}
	return c.JSON(http.StatusOK, dto.DailyLimitResponse{
		Limit:       limit,
		UsedToday:   used,
		LeftToday:   left,
		WindowStart: start,
		WindowEnd:   end,
	})
}

func uidFromCtx(c echo.Context) (uint, error) {
	v := c.Get("uid")
	switch t := v.(type) {
	case uint:
		return t, nil
	case int:
		if t < 0 { return 0, echo.NewHTTPError(http.StatusUnauthorized, "invalid uid") }
		return uint(t), nil
	case int64:
		if t < 0 { return 0, echo.NewHTTPError(http.StatusUnauthorized, "invalid uid") }
		return uint(t), nil
	case float64:
		if t < 0 { return 0, echo.NewHTTPError(http.StatusUnauthorized, "invalid uid") }
		return uint(t), nil
	default:
		return 0, echo.NewHTTPError(http.StatusUnauthorized, "uid missing")
	}
}