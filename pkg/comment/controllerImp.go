package comment

import (
	"net/http"
	"strconv"

	"github.com/RathaTart/FoodBridge/dto"
	"github.com/labstack/echo/v4"
)

// --- controller ---
type controller struct{ svc Service }

func NewController(svc Service) Controller { return &controller{svc: svc} }

func (h *controller) RegisterUnderPosts(posts *echo.Group) {
	posts.POST("/:post_id/comments", h.create) // createComment
	posts.GET("/:post_id/comments", h.list)    // getCommentList
}

func (h *controller) RegisterTopLevel(g *echo.Group) {
	g.PATCH("/:id", h.update) // updateComment
	g.DELETE("/:id", h.delete) // deleteComment
}

// --- handlers ---

func (h *controller) create(c echo.Context) error {
	postID, err := mustUintParam(c, "post_id"); if err != nil { return err }
	uid, err := uidFromCtx(c); if err != nil { return err }

	var req dto.CreateCommentRequest
	if err := c.Bind(&req); err != nil || req.Body == "" {
		return echo.NewHTTPError(http.StatusBadRequest, "bad request")
	}
	resp, err := h.svc.Create(c.Request().Context(), postID, uid, req)
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}
	return c.JSON(http.StatusCreated, resp)
}

func (h *controller) update(c echo.Context) error {
	commentID, err := mustUintParam(c, "id"); if err != nil { return err }
	uid, err := uidFromCtx(c); if err != nil { return err }

	var req dto.UpdateCommentRequest
	if err := c.Bind(&req); err != nil || req.Body == "" {
		return echo.NewHTTPError(http.StatusBadRequest, "bad request")
	}
	resp, err := h.svc.Update(c.Request().Context(), commentID, uid, req)
	if err != nil {
		if err.Error() == "forbidden: not owner" {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}
	return c.JSON(http.StatusOK, resp)
}

func (h *controller) delete(c echo.Context) error {
	commentID, err := mustUintParam(c, "id"); if err != nil { return err }
	uid, err := uidFromCtx(c); if err != nil { return err }

	if err := h.svc.Delete(c.Request().Context(), commentID, uid); err != nil {
		if err.Error() == "forbidden: not owner" {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}
	return c.NoContent(http.StatusNoContent)
}

func (h *controller) list(c echo.Context) error {
	postID, err := mustUintParam(c, "post_id"); if err != nil { return err }

	// parent_id: optional
	var parentID *uint
	if v := c.QueryParam("parent_id"); v != "" {
		id64, err := strconv.ParseUint(v, 10, 64)
		if err != nil { return echo.NewHTTPError(http.StatusBadRequest, "invalid parent_id") }
		tmp := uint(id64)
		parentID = &tmp
	}

	// include_children: optional (default false)
	includeChildren := false
	if v := c.QueryParam("include_children"); v != "" {
		b, err := strconv.ParseBool(v) // true/false/1/0
		if err != nil { return echo.NewHTTPError(http.StatusBadRequest, "invalid include_children") }
		includeChildren = b
	}

	limit := 50
	if v := c.QueryParam("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 200 { limit = n }
	}
	offset := 0
	if v := c.QueryParam("offset"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 { offset = n }
	}

	resp, err := h.svc.List(c.Request().Context(), postID, parentID, limit, offset, includeChildren)
	if err != nil { return echo.NewHTTPError(http.StatusInternalServerError, err.Error()) }

	// ✅ Just return the service response, which now includes `replies` when include_children=true.
	return c.JSON(http.StatusOK, resp)
}



// --- helpers (same style as user/controllerImp.go) ---
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
