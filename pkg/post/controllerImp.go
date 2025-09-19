package post

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/RathaTart/FoodBridge/dto"
	"github.com/labstack/echo/v4"
)

type controllerImpl struct {
	svc Service
}

func NewController(svc Service) Controller {
	return &controllerImpl{svc: svc}
}

// helpers
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

// ===== Post =====
func (h *controllerImpl) Create(c echo.Context) error {
	uid, err := uidFromCtx(c); if err != nil { return err }
	var req dto.CreatePostRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "bad request")
	}
	res, err := h.svc.Create(uid, req)
	if err != nil { return echo.NewHTTPError(http.StatusBadRequest, err.Error()) }
	return c.JSON(http.StatusCreated, res)
}

func (h *controllerImpl) Update(c echo.Context) error {
	uid, err := uidFromCtx(c); if err != nil { return err }
	postID, err := mustUintParam(c, "post_id"); if err != nil { return err }
	var req dto.UpdatePostRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "bad request")
	}
	res, err := h.svc.Update(uid, postID, req)
	if err != nil { return echo.NewHTTPError(http.StatusBadRequest, err.Error()) }
	return c.JSON(http.StatusOK, res)
}

func (h *controllerImpl) Delete(c echo.Context) error {
	uid, err := uidFromCtx(c); if err != nil { return err }
	postID, err := mustUintParam(c, "post_id"); if err != nil { return err }
	if err := h.svc.Delete(uid, postID); err != nil {
		if err.Error() == "forbidden: only owner can modify" {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}
	return c.NoContent(http.StatusNoContent)
}

func (h *controllerImpl) GetByID(c echo.Context) error {
	uid, err := uidFromCtx(c); if err != nil { return err }
	postID, err := mustUintParam(c, "post_id"); if err != nil { return err }
	res, err := h.svc.GetByID(uid, postID)
	if err != nil { return echo.NewHTTPError(http.StatusNotFound, err.Error()) }
	return c.JSON(http.StatusOK, res)
}

func (h *controllerImpl) List(c echo.Context) error {
    uid, err := uidFromCtx(c); if err != nil { return err }
    var q dto.ListPostsQuery

    if v := c.QueryParam("page"); v != "" {
        if n, e := strconv.Atoi(v); e == nil { q.Page = n }
    }
    if v := c.QueryParam("page_size"); v != "" {
        if n, e := strconv.Atoi(v); e == nil { q.PageSize = n }
    }
    q.Q = c.QueryParam("q")
    if v := c.QueryParam("type"); v != "" { vv := v; q.Type = &vv }
    if v := c.QueryParam("status"); v != "" { vv := v; q.Status = &vv }

    // ----- FIX จุดนี้ -----
    rawMine, present := c.QueryParams()["mine"] // เช็คว่ามีพารามิเตอร์นี้จริงไหม
    v := ""
    if present && len(rawMine) > 0 {
        v = strings.TrimSpace(rawMine[0])
    }
    if present { // ถ้าระบุ mine มา แต่ไม่ใส่ค่า → ถือว่า true
        if v == "" {
            b := true
            q.Mine = &b
        } else {
            // รองรับ TRUE/ true / 1 / t / yes / on (และมี space/ตัวพิมพ์ใหญ่)
            lv := strings.ToLower(v)
            switch lv {
            case "1", "t", "true", "yes", "on":
                b := true
                q.Mine = &b
            case "0", "f", "false", "no", "off":
                b := false
                q.Mine = &b
            default:
                // เผื่อใช้ ParseBool อีกชั้น (ถ้ามีรูปแบบอื่น)
                if b, e := strconv.ParseBool(lv); e == nil {
                    q.Mine = &b
                } else {
                    return echo.NewHTTPError(http.StatusBadRequest, "invalid mine")
                }
            }
        }
    }
    // ----------------------

    q.Sort = c.QueryParam("sort")

    res, err := h.svc.List(uid, q)
    if err != nil { return echo.NewHTTPError(http.StatusInternalServerError, err.Error()) }
    return c.JSON(http.StatusOK, res)
}


// ===== PostDetail =====
func (h *controllerImpl) CreateDetail(c echo.Context) error {
	uid, err := uidFromCtx(c); if err != nil { return err }
	postID, err := mustUintParam(c, "post_id"); if err != nil { return err }
	var req dto.CreatePostDetailRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "bad request")
	}
	res, err := h.svc.CreateDetail(uid, postID, req)
	if err != nil { return echo.NewHTTPError(http.StatusBadRequest, err.Error()) }
	return c.JSON(http.StatusCreated, res)
}

func (h *controllerImpl) UpdateDetail(c echo.Context) error {
	uid, err := uidFromCtx(c); if err != nil { return err }
	postID, err := mustUintParam(c, "post_id"); if err != nil { return err }
	detailID, err := mustUintParam(c, "detail_id"); if err != nil { return err }
	var req dto.UpdatePostDetailRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "bad request")
	}
	res, err := h.svc.UpdateDetail(uid, postID, detailID, req)
	if err != nil { return echo.NewHTTPError(http.StatusBadRequest, err.Error()) }
	return c.JSON(http.StatusOK, res)
}

func (h *controllerImpl) DeleteDetail(c echo.Context) error {
	uid, err := uidFromCtx(c); if err != nil { return err }
	postID, err := mustUintParam(c, "post_id"); if err != nil { return err }
	detailID, err := mustUintParam(c, "detail_id"); if err != nil { return err }
	if err := h.svc.DeleteDetail(uid, postID, detailID); err != nil {
		if err.Error() == "forbidden: only owner can modify" {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}
	return c.NoContent(http.StatusNoContent)
}

func (h *controllerImpl) ListDetails(c echo.Context) error {
	uid, err := uidFromCtx(c); if err != nil { return err }
	postID, err := mustUintParam(c, "post_id"); if err != nil { return err }
	res, err := h.svc.ListDetails(uid, postID)
	if err != nil { return echo.NewHTTPError(http.StatusInternalServerError, err.Error()) }
	return c.JSON(http.StatusOK, res)
}
