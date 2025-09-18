package server

import (
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"

	"github.com/RathaTart/FoodBridge/config"
)

func useMiddlewares(e *echo.Echo) {
	e.HideBanner = true
	e.Use(middleware.Recover())
	e.Use(middleware.Logger())
	e.Use(middleware.CORS())
}

// AuthMiddleware: บังคับต้องมี JWT ยกเว้น white-list
func AuthMiddleware() echo.MiddlewareFunc {
	cfg := config.Load()
	secret := []byte(cfg.JWTSecret)

	// path ที่อนุญาตแบบสาธารณะ
	publicPaths := map[string]struct{}{
		"/health":                 {},
		"/api/v1/auth/login":     {},
		"/api/v1/auth/register":  {},
	}

	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			// อนุญาต public path
			if _, ok := publicPaths[c.Path()]; ok {
				return next(c)
			}

			// ดึง header Authorization
			auth := c.Request().Header.Get("Authorization")
			parts := strings.SplitN(auth, " ", 2)
			if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
				return echo.NewHTTPError(http.StatusUnauthorized, "missing or malformed jwt")
			}
			tokenStr := parts[1]

			// parse/validate token
			token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
				// จำกัด alg เป็น HS256
				if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
					return nil, echo.NewHTTPError(http.StatusUnauthorized, "unexpected jwt signing method")
				}
				return secret, nil
			})
			if err != nil || !token.Valid {
				return echo.NewHTTPError(http.StatusUnauthorized, "invalid or expired jwt")
			}

			// เก็บ claim ไว้ใน context (เช่น uid/role)
			if claims, ok := token.Claims.(jwt.MapClaims); ok {
				if uid, ok2 := claims["uid"]; ok2 {
					c.Set("uid", uid)
				}
				if role, ok2 := claims["role"]; ok2 {
					c.Set("role", role)
				}
			}

			return next(c)
		}
	}
}
