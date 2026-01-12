package user

import (
	"net/http"
	"fmt"
	"strconv"

	"github.com/RathaTart/FoodBridge/dto"
	"github.com/labstack/echo/v4"
)

type controllerImpl struct{ svc Service }

func NewController(svc Service) Controller { return &controllerImpl{svc: svc} }


// ---------- helpers ----------
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

func (h *controllerImpl) Register(c echo.Context) error {
	var req dto.RegisterRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, echo.Map{"error": "bad request"})
	}
	resp, err := h.svc.Register(req)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, echo.Map{"error": err.Error()})
	}
	return c.JSON(http.StatusCreated, resp)
}

func (h *controllerImpl) Login(c echo.Context) error {
	var req dto.LoginRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, echo.Map{"error": "bad request"})
	}
	resp, err := h.svc.Login(req)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, echo.Map{"error": err.Error()})
	}
	return c.JSON(http.StatusOK, resp)
}

func (h *controllerImpl) GetByID(c echo.Context) error {
	idStr := c.Param("id")
	var id uint
	_, err := fmt.Sscanf(idStr, "%d", &id)
	if err != nil {
		return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid id"})
	}
	resp, err := h.svc.GetByID(id)
	if err != nil {
		return c.JSON(http.StatusNotFound, echo.Map{"error": err.Error()})
	}
	return c.JSON(http.StatusOK, resp)
}

func (h *controllerImpl) Me(c echo.Context) error {
	uid, err := uidFromCtx(c); if err != nil { return err }
	res, err := h.svc.Me(uid)
	if err != nil { return echo.NewHTTPError(http.StatusNotFound, err.Error()) }
	return c.JSON(http.StatusOK, res)
}

func (h *controllerImpl) UpdateMe(c echo.Context) error {
	uid, err := uidFromCtx(c); if err != nil { return err }
	var req dto.UpdateMeRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "bad request")
	}
	res, err := h.svc.UpdateMe(uid, req)
	if err != nil { return echo.NewHTTPError(http.StatusBadRequest, err.Error()) }
	return c.JSON(http.StatusOK, res)
}

func (h *controllerImpl) ChangeMyPassword(c echo.Context) error {
	uid, err := uidFromCtx(c); if err != nil { return err }
	var req dto.ChangePasswordRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "bad request")
	}
	if err := h.svc.ChangeMyPassword(uid, req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}
	return c.NoContent(http.StatusNoContent)
}

func (h *controllerImpl) List(c echo.Context) error {
	var q dto.ListUsersQuery

	// --- page / page_size ---
	if v := c.QueryParam("page"); v != "" {
		if n, err := strconv.Atoi(v); err != nil || n <= 0 {
			return echo.NewHTTPError(http.StatusBadRequest, "invalid page")
		} else { q.Page = n }
	}
	if v := c.QueryParam("page_size"); v != "" {
		if n, err := strconv.Atoi(v); err != nil || n <= 0 {
			return echo.NewHTTPError(http.StatusBadRequest, "invalid page_size")
		} else { q.PageSize = n }
	}

	// --- q (keyword) ---
	q.Q = c.QueryParam("q")

	// --- verified (optional bool pointer) ---
	if v := c.QueryParam("verified"); v != "" {
		b, err := strconv.ParseBool(v) // true/false/1/0
		if err != nil {
			return echo.NewHTTPError(http.StatusBadRequest, "invalid verified")
		}
		q.Verified = &b
	}

	// --- sort ---
	q.Sort = c.QueryParam("sort") // "", created_at, -created_at, full_name, -full_name

	res, err := h.svc.List(q)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}
	return c.JSON(http.StatusOK, res)
}

func (h *controllerImpl) Delete(c echo.Context) error {
	uid, err := uidFromCtx(c); if err != nil { return err }
	targetID, err := mustUintParam(c, "id"); if err != nil { return err }

	if err := h.svc.Delete(uid, targetID); err != nil {
		// ถ้า uid != targetID จะได้ 403
		if err.Error() == "forbidden: can only delete yourself" {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}
	return c.NoContent(http.StatusNoContent)
}

func (h *controllerImpl) GetMyShareLink(c echo.Context) error {
	uid, err := uidFromCtx(c); if err != nil { return err }
	res, err := h.svc.GetMyShareLink(uid)
	if err != nil { return echo.NewHTTPError(http.StatusInternalServerError, err.Error()) }
	return c.JSON(http.StatusOK, res)
}

func (h *controllerImpl) GetShareLinkByID(c echo.Context) error {
	id, err := mustUintParam(c, "id"); if err != nil { return err }
	res, err := h.svc.GetShareLinkByID(id)
	if err != nil { return echo.NewHTTPError(http.StatusNotFound, err.Error()) }
	return c.JSON(http.StatusOK, res)
}


