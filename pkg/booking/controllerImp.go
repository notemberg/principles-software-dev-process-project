package booking

import (
	"net/http"
	"strconv"

	"github.com/RathaTart/FoodBridge/dto"
	"github.com/RathaTart/FoodBridge/entities"
	"github.com/labstack/echo/v4"
)

type controller struct{ svc Service }

func NewController(svc Service) Controller { return &controller{svc: svc} }

// ---------- /bookings ----------
func (h *controller) Register(g *echo.Group) {
	// GET    /bookings                      -> getBookingList
	g.GET("", h.list)

	// GET    /bookings/:id                  -> getBookingByID
	g.GET("/:id", h.get)

	// PATCH  /bookings/:id                  -> updateBookingStatus
	g.PATCH("/:id", h.updateStatus)

	// POST   /bookings/:id/qr               -> createBookingQR
	g.POST("/:id/qr", h.issueQR)

	// POST   /bookings/scan                 -> scanBookingQR
	g.POST("/scan", h.scan)
}

// ---------- /posts ----------
func (h *controller) RegisterUnderPosts(posts *echo.Group) {
	// POST /posts/:post_id/bookings -> createBooking
	posts.POST("/:post_id/bookings", h.create)
}

// ====== handlers ======

func (h *controller) list(c echo.Context) error {
	var f Filter
	if v := c.QueryParam("post_id"); v != "" {
		if id, err := strconv.ParseInt(v, 10, 64); err == nil { f.PostID = &id }
	}
	if v := c.QueryParam("receiver_user_id"); v != "" {
		if id, err := strconv.ParseInt(v, 10, 64); err == nil { f.ReceiverUserID = &id }
	}
	if v := c.QueryParam("status"); v != "" {
		s := entities.BookingStatus(v)
		f.Status = &s
	}

	out, err := h.svc.List(c.Request().Context(), f)
	if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()}) }
	return c.JSON(http.StatusOK, dto.FromEntities(out))
}

func (h *controller) get(c echo.Context) error {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error":"bad_id"}) }

	b, err := h.svc.Get(c.Request().Context(), id)
	if err != nil { return c.JSON(http.StatusNotFound, echo.Map{"error":"not_found"}) }
	return c.JSON(http.StatusOK, dto.FromEntity(b))
}

func (h *controller) updateStatus(c echo.Context) error {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error":"bad_id"}) }

	var req dto.UpdateStatusRequest
	if err := c.Bind(&req); err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error":"bad_json"}) }

	b, err := h.svc.UpdateStatus(c.Request().Context(), id, req.Status)
	if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()}) }
	return c.JSON(http.StatusOK, dto.FromEntity(b))
}

func (h *controller) issueQR(c echo.Context) error {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error":"bad_id"}) }

	tok, err := h.svc.IssueQR(c.Request().Context(), id)
	if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()}) }
	return c.JSON(http.StatusOK, dto.IssueQRResponse{QRToken: tok})
}

func (h *controller) scan(c echo.Context) error {
	var req dto.ScanQRRequest
	if err := c.Bind(&req); err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error":"bad_json"}) }

	b, err := h.svc.ScanQR(c.Request().Context(), req.QRToken)
	if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()}) }
	return c.JSON(http.StatusOK, dto.FromEntity(b))
}

func (h *controller) create(c echo.Context) error {
	postID, err := strconv.ParseInt(c.Param("post_id"), 10, 64)
	if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error":"bad_post_id"}) }

	receiverID := currentUserID(c) // replace with your auth middleware later
	if receiverID == 0 { return c.JSON(http.StatusUnauthorized, echo.Map{"error":"unauthorized"}) }

	b, err := h.svc.Create(c.Request().Context(), postID, receiverID)
	if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()}) }
	return c.JSON(http.StatusCreated, dto.FromEntity(b))
}

// TEMP auth helper until your auth middleware is wired
func currentUserID(c echo.Context) int64 {
	if v := c.Get("user_id"); v != nil {
		if id, ok := v.(int64); ok && id > 0 { return id }
	}
	if hv := c.Request().Header.Get("X-User-ID"); hv != "" {
		if id, err := strconv.ParseInt(hv, 10, 64); err == nil && id > 0 { return id }
	}
	return 0
}
