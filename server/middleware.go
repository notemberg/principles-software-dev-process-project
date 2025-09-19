package server

import (
	"net/http"
	"strings"

	jwtv5 "github.com/golang-jwt/jwt/v5"
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

// -------------------- AUTH --------------------

// AuthMiddleware: ตรวจ JWT แล้วใส่ uid/role ลง context
// อนุญาต path สาธารณะ (login/register/health)
func AuthMiddleware() echo.MiddlewareFunc {
	cfg := config.Load()
	secret := []byte(cfg.JWTSecret)

	publicPaths := map[string]struct{}{
		"/health":              {},
		"/auth/login":          {},
		"/auth/register":       {},
		"/api/v1/auth/login":   {},
		"/api/v1/auth/register": {},
	}

	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			// อนุญาตเส้นทาง public
			if _, ok := publicPaths[c.Path()]; ok {
				return next(c)
			}

			// อ่าน Authorization: Bearer <token>
			auth := c.Request().Header.Get("Authorization")
			parts := strings.SplitN(auth, " ", 2)
			if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
				return echo.NewHTTPError(http.StatusUnauthorized, "missing or malformed jwt")
			}
			tokenStr := parts[1]

			token, err := jwtv5.Parse(tokenStr, func(t *jwtv5.Token) (interface{}, error) {
				if _, ok := t.Method.(*jwtv5.SigningMethodHMAC); !ok {
					return nil, echo.NewHTTPError(http.StatusUnauthorized, "unexpected jwt signing method")
				}
				return secret, nil
			})
			if err != nil || !token.Valid {
				return echo.NewHTTPError(http.StatusUnauthorized, "invalid or expired jwt")
			}

			// set uid/role ลง context (แปลงชนิดให้เรียบร้อย)
			if claims, ok := token.Claims.(jwtv5.MapClaims); ok {
				// uid อาจเป็น float64 จาก JSON
				if v, ok := claims["uid"]; ok {
					switch t := v.(type) {
					case float64:
						c.Set("uid", uint(t))
					case int:
						c.Set("uid", uint(t))
					case int64:
						c.Set("uid", uint(t))
					case string:
						// ไม่คาดหวังเป็น string แต่กันไว้
						c.Set("uid", t)
					default:
						c.Set("uid", v)
					}
				}
				if role, ok := claims["role"]; ok {
					if rs, ok := role.(string); ok {
						c.Set("role", rs)
					} else {
						c.Set("role", role)
					}
				}
			}

			return next(c)
		}
	}
}

// AdminOnly: อนุญาตเฉพาะผู้ใช้ role=ADMIN
func AdminOnly() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			roleAny := c.Get("role")
			role, _ := roleAny.(string)
			if strings.ToUpper(role) != "ADMIN" {
				return echo.NewHTTPError(http.StatusForbidden, "admin only")
			}
			return next(c)
		}
	}
}
