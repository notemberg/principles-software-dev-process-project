package verification

import (
    "net/http"
    "strconv"
    "strings"

    "github.com/RathaTart/FoodBridge/dto"
    "github.com/labstack/echo/v4"
)

type controllerImpl struct{ svc Service }
func NewController(svc Service) Controller { return &controllerImpl{svc: svc} }

func uidFromCtx(c echo.Context) (uint, error) {
    v := c.Get("uid")
    switch t := v.(type) {
    case uint: return t, nil
    case int: if t<0 {return 0, echo.NewHTTPError(http.StatusUnauthorized)}; return uint(t), nil
    case int64: if t<0 {return 0, echo.NewHTTPError(http.StatusUnauthorized)}; return uint(t), nil
    case float64: if t<0 {return 0, echo.NewHTTPError(http.StatusUnauthorized)}; return uint(t), nil
    default: return 0, echo.NewHTTPError(http.StatusUnauthorized, "uid missing")
    }
}

func (h *controllerImpl) Create(c echo.Context) error {
    uid, err := uidFromCtx(c); if err != nil { return err }
    var req dto.CreateVerificationRequest
    if err := c.Bind(&req); err != nil {
        return echo.NewHTTPError(http.StatusBadRequest, "bad request")
    }
    res, err := h.svc.Create(uid, req)
    if err != nil { return echo.NewHTTPError(http.StatusBadRequest, err.Error()) }
    return c.JSON(http.StatusCreated, res)
}

func (h *controllerImpl) AdminList(c echo.Context) error {
    uid, err := uidFromCtx(c); if err != nil { return err }
    status := strings.TrimSpace(c.QueryParam("status")) // default = ""
    res, err := h.svc.ListAdmin(uid, status)
    if err != nil {
        if strings.HasPrefix(err.Error(), "forbidden") {
            return echo.NewHTTPError(http.StatusForbidden, err.Error())
        }
        return echo.NewHTTPError(http.StatusBadRequest, err.Error())
    }
    return c.JSON(http.StatusOK, res)
}

func (h *controllerImpl) Approve(c echo.Context) error {
    uid, err := uidFromCtx(c); if err != nil { return err }
    id, err := strconv.ParseUint(c.Param("id"), 10, 64)
    if err != nil { return echo.NewHTTPError(http.StatusBadRequest, "invalid id") }
    res, err := h.svc.Approve(uid, uint(id))
    if err != nil {
        if strings.HasPrefix(err.Error(), "forbidden") {
            return echo.NewHTTPError(http.StatusForbidden, err.Error())
        }
        return echo.NewHTTPError(http.StatusBadRequest, err.Error())
    }
    return c.JSON(http.StatusOK, res)
}

func (h *controllerImpl) Reject(c echo.Context) error {
    uid, err := uidFromCtx(c); if err != nil { return err }
    id, err := strconv.ParseUint(c.Param("id"), 10, 64)
    if err != nil { return echo.NewHTTPError(http.StatusBadRequest, "invalid id") }
    var req dto.RejectRequest
    if err := c.Bind(&req); err != nil {
        return echo.NewHTTPError(http.StatusBadRequest, "bad request")
    }
    res, err := h.svc.Reject(uid, uint(id), req.Note)
    if err != nil {
        if strings.HasPrefix(err.Error(), "forbidden") {
            return echo.NewHTTPError(http.StatusForbidden, err.Error())
        }
        return echo.NewHTTPError(http.StatusBadRequest, err.Error())
    }
    return c.JSON(http.StatusOK, res)
}
