package notification

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/RathaTart/FoodBridge/dto"
	"github.com/labstack/echo/v4"
)

// keep your Controller interface as-is; this impl matches your post/controller pattern
type controllerImpl struct {
	svc Service
}

func NewController(svc Service) Controller { return &controllerImpl{svc: svc} }

// ===== helpers (copied to match post controller behavior) =====
func uidFromCtx(c echo.Context) (uint, error) {
	v := c.Get("uid")
	switch t := v.(type) {
	case uint:
		return t, nil
	case int:
		if t < 0 {
			return 0, echo.NewHTTPError(http.StatusUnauthorized, "invalid uid")
		}
		return uint(t), nil
	case int64:
		if t < 0 {
			return 0, echo.NewHTTPError(http.StatusUnauthorized, "invalid uid")
		}
		return uint(t), nil
	case float64:
		if t < 0 {
			return 0, echo.NewHTTPError(http.StatusUnauthorized, "invalid uid")
		}
		return uint(t), nil
	default:
		return 0, echo.NewHTTPError(http.StatusUnauthorized, "uid missing")
	}
}

func mustInt64Param(c echo.Context, name string) (int64, error) {
	idStr := c.Param(name)
	id64, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil || id64 <= 0 {
		return 0, echo.NewHTTPError(http.StatusBadRequest, "invalid id")
	}
	return id64, nil
}

// ===== routes binder =====
func (h *controllerImpl) Register(g *echo.Group) {
	g.GET("", h.list)
	g.GET("/unread-count", h.unreadCount)
	g.PATCH("/:id/read", h.markRead)
	g.DELETE("/:id", h.delete)
}

// ===== handlers =====

// GET /notifications?unread=1&page=1&page_size=20
func (h *controllerImpl) list(c echo.Context) error {
	uid, err := uidFromCtx(c)
	if err != nil { return err }

	var q dto.ListNotificationsQuery

	// page / page_size (follow your robust style)
	if v := c.QueryParam("page"); v != "" {
		if n, e := strconv.Atoi(v); e == nil && n > 0 { q.Page = n }
	}
	if v := c.QueryParam("page_size"); v != "" {
		if n, e := strconv.Atoi(v); e == nil && n > 0 { q.PageSize = n }
	}

	// unread (accept 1/true/yes/on)
	if raw, ok := c.QueryParams()["unread"]; ok && len(raw) > 0 {
		s := strings.TrimSpace(strings.ToLower(raw[0]))
		switch s {
		case "", "1", "t", "true", "yes", "on":
			q.Unread = true
		case "0", "f", "false", "no", "off":
			q.Unread = false
		default:
			if b, e := strconv.ParseBool(s); e == nil {
				q.Unread = b
			} else {
				return echo.NewHTTPError(http.StatusBadRequest, "invalid unread")
			}
		}
	}

	// convert uid(uint) -> int64 for service (which uses int64)
	res, err := h.svc.List(c.Request().Context(), int64(uid), q)
	if err != nil { return echo.NewHTTPError(http.StatusInternalServerError, err.Error()) }
	return c.JSON(http.StatusOK, res)
}

// GET /notifications/unread-count
func (h *controllerImpl) unreadCount(c echo.Context) error {
	uid, err := uidFromCtx(c)
	if err != nil { return err }
	n, err := h.svc.UnreadCount(c.Request().Context(), int64(uid))
	if err != nil { return echo.NewHTTPError(http.StatusInternalServerError, err.Error()) }
	return c.JSON(http.StatusOK, dto.UnreadCountResponse{Unread: n})
}

// PATCH /notifications/:id/read
func (h *controllerImpl) markRead(c echo.Context) error {
	uid, err := uidFromCtx(c)
	if err != nil { return err }
	id, err := mustInt64Param(c, "id")
	if err != nil { return err }
	if err := h.svc.MarkRead(c.Request().Context(), id, int64(uid)); err != nil {
		// your project usually returns 404 via echo.HTTPError/ErrRecordNotFound mapping in repo/service
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}
	return c.NoContent(http.StatusNoContent)
}

// DELETE /notifications/:id
func (h *controllerImpl) delete(c echo.Context) error {
	uid, err := uidFromCtx(c)
	if err != nil { return err }
	id, err := mustInt64Param(c, "id")
	if err != nil { return err }
	if err := h.svc.Delete(c.Request().Context(), id, int64(uid)); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}
	return c.NoContent(http.StatusNoContent)
}
