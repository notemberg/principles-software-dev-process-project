package report

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/RathaTart/FoodBridge/dto"
	"github.com/labstack/echo/v4"
)

type controllerImpl struct{ svc Service }

func NewController(svc Service) Controller { return &controllerImpl{svc: svc} }

// helpers (เหมือนที่ใช้ใน pkg/post)
func uidFromCtx(c echo.Context) (uint, error) {
	v := c.Get("uid")
	switch t := v.(type) {
	case uint: return t, nil
	case int: if t<0 {return 0, echo.NewHTTPError(http.StatusUnauthorized,"invalid uid")} ; return uint(t), nil
	case int64: if t<0 {return 0, echo.NewHTTPError(http.StatusUnauthorized,"invalid uid")} ; return uint(t), nil
	case float64: if t<0 {return 0, echo.NewHTTPError(http.StatusUnauthorized,"invalid uid")} ; return uint(t), nil
	default: return 0, echo.NewHTTPError(http.StatusUnauthorized, "uid missing")
	}
}
func mustUintParam(c echo.Context, name string) (uint, error) {
	idStr := strings.TrimSpace(c.Param(name))
	id64, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil { return 0, echo.NewHTTPError(http.StatusBadRequest, "invalid id") }
	return uint(id64), nil
}

func (h *controllerImpl) Create(c echo.Context) error {
	uid, err := uidFromCtx(c); if err != nil { return err }
	postID, err := mustUintParam(c, "post_id"); if err != nil { return err }
	var req dto.CreateReportRequest
	if err := c.Bind(&req); err != nil { return echo.NewHTTPError(http.StatusBadRequest, "bad request") }
	res, err := h.svc.Create(uid, postID, req)
	if err != nil { return echo.NewHTTPError(http.StatusBadRequest, err.Error()) }
	return c.JSON(http.StatusCreated, res)
}

func (h *controllerImpl) ListForPost(c echo.Context) error {
	uid, err := uidFromCtx(c); if err != nil { return err }
	postID, err := mustUintParam(c, "post_id"); if err != nil { return err }
	res, err := h.svc.ListForPost(uid, postID)
	if err != nil {
		if strings.HasPrefix(err.Error(), "forbidden") {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}
	return c.JSON(http.StatusOK, res)
}

func (h *controllerImpl) ListMine(c echo.Context) error {
	uid, err := uidFromCtx(c); if err != nil { return err }
	res, err := h.svc.ListMine(uid)
	if err != nil { return echo.NewHTTPError(http.StatusInternalServerError, err.Error()) }
	return c.JSON(http.StatusOK, res)
}

func (h *controllerImpl) UpdateStatus(c echo.Context) error {
	uid, err := uidFromCtx(c); if err != nil { return err }
	reportID, err := mustUintParam(c, "report_id"); if err != nil { return err }
	var req dto.UpdateReportStatusRequest
	if err := c.Bind(&req); err != nil { return echo.NewHTTPError(http.StatusBadRequest, "bad request") }
	res, err := h.svc.UpdateStatus(uid, reportID, req.Status)
	if err != nil {
		if strings.HasPrefix(err.Error(), "forbidden") {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}
	return c.JSON(http.StatusOK, res)
}
