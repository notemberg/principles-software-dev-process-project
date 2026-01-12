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
	if err := c.Bind(&req); err != nil { return echo.NewHTTPError(http.StatusBadRequest, "bad request") }
	res, err := h.svc.Create(uid, req)
	if err != nil { return echo.NewHTTPError(http.StatusBadRequest, err.Error()) }
	return c.JSON(http.StatusCreated, res)
}

func (h *controllerImpl) Update(c echo.Context) error {
	uid, err := uidFromCtx(c); if err != nil { return err }
	postID, err := mustUintParam(c, "post_id"); if err != nil { return err }
	var req dto.UpdatePostRequest
	if err := c.Bind(&req); err != nil { return echo.NewHTTPError(http.StatusBadRequest, "bad request") }
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

	// page / page_size
	if v := c.QueryParam("page"); v != "" {
		if n, e := strconv.Atoi(v); e == nil { q.Page = n }
	}
	if v := c.QueryParam("page_size"); v != "" {
		if n, e := strconv.Atoi(v); e == nil { q.PageSize = n }
	}

	// search / status / is_giveaway / category / mine / sort
	q.Q = c.QueryParam("q")

	if v := c.QueryParam("status"); v != "" {
		vv := v; q.Status = &vv
	}
	if v := c.QueryParam("is_giveaway"); v != "" {
		if b, e := strconv.ParseBool(strings.TrimSpace(v)); e == nil {
			q.IsGiveaway = &b
		} else { return echo.NewHTTPError(http.StatusBadRequest, "invalid is_giveaway") }
	}
	if v := c.QueryParam("category"); v != "" {
		vv := strings.TrimSpace(v); q.Category = &vv
	}
	if raw, ok := c.QueryParams()["mine"]; ok && len(raw) > 0 {
		s := strings.TrimSpace(raw[0])
		if s == "" { b := true; q.Mine = &b } else {
			ls := strings.ToLower(s)
			switch ls {
			case "1","t","true","yes","on":
				b := true; q.Mine = &b
			case "0","f","false","no","off":
				b := false; q.Mine = &b
			default:
				if b, e := strconv.ParseBool(ls); e == nil { q.Mine = &b
				} else { return echo.NewHTTPError(http.StatusBadRequest, "invalid mine") }
			}
		}
	}
	q.Sort = c.QueryParam("sort")

	// NEW: post_type
	if v := c.QueryParam("post_type"); v != "" {
		vv := strings.ToUpper(strings.TrimSpace(v))
		q.PostType = &vv
	}

	res, err := h.svc.List(uid, q)
	if err != nil { return echo.NewHTTPError(http.StatusInternalServerError, err.Error()) }
	return c.JSON(http.StatusOK, res)
}

func (h *controllerImpl) ListByUser(c echo.Context) error {
    // ไม่ต้องใช้ uid จาก token ก็ได้ เพราะเป็นการดู profile คนอื่น
    _, _ = uidFromCtx(c) // ถ้าระบบคุณต้องการให้ล็อกอินก่อน ก็คงไว้

    // อ่าน :id จาก path
    userID, err := mustUintParam(c, "id")
    if err != nil {
        return err
    }

    var q dto.ListPostsQuery

    // page / page_size
    if v := c.QueryParam("page"); v != "" {
        if n, e := strconv.Atoi(v); e == nil { q.Page = n }
    }
    if v := c.QueryParam("page_size"); v != "" {
        if n, e := strconv.Atoi(v); e == nil { q.PageSize = n }
    }

    // ตัวกรองทั่วไป (เหมือน List)
    q.Q = c.QueryParam("q")
    if v := c.QueryParam("status"); v != "" { vv := v; q.Status = &vv }
    if v := c.QueryParam("is_giveaway"); v != "" {
        if b, e := strconv.ParseBool(strings.TrimSpace(v)); e == nil { q.IsGiveaway = &b
        } else { return echo.NewHTTPError(http.StatusBadRequest, "invalid is_giveaway") }
    }
    if v := c.QueryParam("category"); v != "" { vv := strings.TrimSpace(v); q.Category = &vv }
    q.Sort = c.QueryParam("sort")
    if v := c.QueryParam("post_type"); v != "" {
        vv := strings.ToUpper(strings.TrimSpace(v))
        q.PostType = &vv
    }

    // ใส่ ProviderID เพื่อบังคับดูโพสต์ของ user คนนั้น
    q.ProviderID = &userID

    // เรียกใช้เหมือนเดิม
    uid, _ := uidFromCtx(c) // ถ้าไม่ต้องใช้สิทธิ์พิเศษ ค่า uid ไม่ได้มีผล เพราะเราเซ็ต ProviderID ไปแล้ว
    res, err := h.svc.List(uid, q)
    if err != nil { return echo.NewHTTPError(http.StatusInternalServerError, err.Error()) }
    return c.JSON(http.StatusOK, res)
}


// ===== PostDetail =====
func (h *controllerImpl) CreateDetail(c echo.Context) error {
	uid, err := uidFromCtx(c)
	if err != nil {
		return err
	}
	postID, err := mustUintParam(c, "post_id")
	if err != nil {
		return err
	}
	var req dto.CreatePostDetailRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "bad request")
	}
	res, err := h.svc.CreateDetail(uid, postID, req)
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}
	return c.JSON(http.StatusCreated, res)
}

func (h *controllerImpl) UpdateDetail(c echo.Context) error {
	uid, err := uidFromCtx(c)
	if err != nil {
		return err
	}
	postID, err := mustUintParam(c, "post_id")
	if err != nil {
		return err
	}
	detailID, err := mustUintParam(c, "detail_id")
	if err != nil {
		return err
	}
	var req dto.UpdatePostDetailRequest
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "bad request")
	}
	res, err := h.svc.UpdateDetail(uid, postID, detailID, req)
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}
	return c.JSON(http.StatusOK, res)
}

func (h *controllerImpl) DeleteDetail(c echo.Context) error {
	uid, err := uidFromCtx(c)
	if err != nil {
		return err
	}
	postID, err := mustUintParam(c, "post_id")
	if err != nil {
		return err
	}
	detailID, err := mustUintParam(c, "detail_id")
	if err != nil {
		return err
	}
	if err := h.svc.DeleteDetail(uid, postID, detailID); err != nil {
		if err.Error() == "forbidden: only owner can modify" {
			return echo.NewHTTPError(http.StatusForbidden, err.Error())
		}
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}
	return c.NoContent(http.StatusNoContent)
}

func (h *controllerImpl) ListDetails(c echo.Context) error {
	uid, err := uidFromCtx(c)
	if err != nil {
		return err
	}
	postID, err := mustUintParam(c, "post_id")
	if err != nil {
		return err
	}
	res, err := h.svc.ListDetails(uid, postID)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}
	return c.JSON(http.StatusOK, res)
}
