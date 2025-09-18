package user

import (
	"net/http"
	"fmt"

	"github.com/RathaTart/FoodBridge/dto"
	"github.com/labstack/echo/v4"
)

type controllerImpl struct{ svc Service }

func NewController(svc Service) Controller { return &controllerImpl{svc: svc} }

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

func (h *controllerImpl) UpdateProfile(c echo.Context) error {
	var req dto.UpdateProfileRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, echo.Map{"error": "bad request"})
	}
	idStr := c.Param("id")
	var id uint
	_, err := fmt.Sscanf(idStr, "%d", &id)
	if err != nil {
		return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid id"})
	}
	resp, err := h.svc.UpdateProfile(id, req)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, echo.Map{"error": err.Error()})
	}
	return c.JSON(http.StatusOK, resp)
}
