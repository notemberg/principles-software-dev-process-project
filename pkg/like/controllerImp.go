package like

import (
	"net/http"
	"strconv"

	"github.com/labstack/echo/v4"
)

// ---------- controller ----------
type controller struct{ svc Service }

func NewController(svc Service) Controller { return &controller{svc: svc} }

func (h *controller) RegisterUnderPosts(posts *echo.Group) {
	posts.POST("/:post_id/like", h.toggle) // toggle like
	posts.GET("/:post_id/likes", h.list)   // list likes
}

func (h *controller) toggle(c echo.Context) error {
	postID, err := mustUintParam(c, "post_id")
	if err != nil { return err }

	uid, err := uidFromCtx(c)
	if err != nil { return err }

	resp, err := h.svc.Toggle(c.Request().Context(), postID, uid)
	if err != nil { return echo.NewHTTPError(http.StatusInternalServerError, err.Error()) }
	return c.JSON(http.StatusOK, resp)
}

func (h *controller) list(c echo.Context) error {
	postID, err := mustUintParam(c, "post_id")
	if err != nil { return err }

	limit := 50
	if v := c.QueryParam("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 200 { limit = n }
	}
	offset := 0
	if v := c.QueryParam("offset"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 { offset = n }
	}

	resp, err := h.svc.List(c.Request().Context(), postID, limit, offset)
	if err != nil { return echo.NewHTTPError(http.StatusInternalServerError, err.Error()) }
	return c.JSON(http.StatusOK, resp)
}

// ---------- helpers (same style as user/controllerImp.go) ----------
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

func mustUintParam(c echo.Context, name string) (uint, error) {
	idStr := c.Param(name)
	id64, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil { return 0, echo.NewHTTPError(http.StatusBadRequest, "invalid id") }
	return uint(id64), nil
}
