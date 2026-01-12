package server

import (
	"net/http"
	"os"
	"strings"
	"time"

	jwtv5 "github.com/golang-jwt/jwt/v5"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"

	"github.com/RathaTart/FoodBridge/config"
)

/* -------------------- BASE MIDDLEWARES -------------------- */

func useMiddlewares(e *echo.Echo) {
	e.HideBanner = true
	e.Use(middleware.Recover())
	e.Use(middleware.Logger())
	e.Use(middleware.CORS())
}

/* -------------------- AUTH -------------------- */

// AuthMiddleware ตรวจ JWT แล้วใส่ uid/role ลง context
// อนุญาต path สาธารณะ: /health, /auth/*, /api/v1/auth/*, และ OPTIONS (preflight)
func AuthMiddleware() echo.MiddlewareFunc {
	cfg := config.Load()
	secret := strings.TrimSpace(cfg.JWTSecret)
	debug := os.Getenv("DEBUG_AUTH") == "1"

	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			// 0) อนุญาต OPTIONS preflight
			if c.Request().Method == http.MethodOptions {
				return next(c)
			}

			path := c.Path()

			// 1) อนุญาต public paths
			if path == "/health" ||
				strings.HasPrefix(path, "/auth/") ||
				strings.HasPrefix(path, "/api/v1/auth/") {
				return next(c)
			}

			// 2) ตรวจว่า server ตั้ง JWT_SECRET แล้วหรือยัง
			if secret == "" {
				if debug {
					c.Logger().Warn("AUTH DEBUG: missing JWT_SECRET in environment/config")
				}
				return echo.NewHTTPError(http.StatusInternalServerError, "server jwt not configured")
			}

			// 3) อ่านและตรวจ Header Authorization: Bearer <token>
			auth := strings.TrimSpace(c.Request().Header.Get("Authorization"))
			parts := strings.SplitN(auth, " ", 2)
			if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
				if debug {
					c.Logger().Warnf("AUTH DEBUG: malformed auth header: %q", auth)
				}
				return echo.NewHTTPError(http.StatusUnauthorized, "missing or malformed jwt")
			}
			tokenStr := strings.TrimSpace(parts[1])
			if tokenStr == "" {
				if debug {
					c.Logger().Warn("AUTH DEBUG: empty bearer token")
				}
				return echo.NewHTTPError(http.StatusUnauthorized, "missing or malformed jwt")
			}

			// 4) Parse + verify ลายเซ็น
			token, err := jwtv5.Parse(tokenStr, func(t *jwtv5.Token) (interface{}, error) {
				// อนุญาตเฉพาะ HMAC
				if _, ok := t.Method.(*jwtv5.SigningMethodHMAC); !ok {
					if debug {
						c.Logger().Warnf("AUTH DEBUG: unexpected signing method: %T", t.Method)
					}
					return nil, echo.NewHTTPError(http.StatusUnauthorized, "unexpected jwt signing method")
				}
				return []byte(secret), nil
			})
			if err != nil || !token.Valid {
				if debug {
					c.Logger().Warnf("AUTH DEBUG: verify failed: %v", err)
				}
				return echo.NewHTTPError(http.StatusUnauthorized, "invalid or expired jwt")
			}

			// 5) ดึง claims + ตรวจ exp เองกันพลาด
			if claims, ok := token.Claims.(jwtv5.MapClaims); ok {
				// ตรวจ exp (ถ้ามี)
				if rawExp, ok := claims["exp"]; ok {
					switch v := rawExp.(type) {
					case float64:
						exp := time.Unix(int64(v), 0)
						// เผื่อเวลาเพี้ยนเล็กน้อย 5 วินาที
						if time.Now().After(exp.Add(0)) {
							if debug {
								c.Logger().Warnf("AUTH DEBUG: token expired at %s", exp.Format(time.RFC3339))
							}
							return echo.NewHTTPError(http.StatusUnauthorized, "invalid or expired jwt")
						}
					case int64:
						exp := time.Unix(v, 0)
						if time.Now().After(exp) {
							if debug {
								c.Logger().Warnf("AUTH DEBUG: token expired at %s", exp.Format(time.RFC3339))
							}
							return echo.NewHTTPError(http.StatusUnauthorized, "invalid or expired jwt")
						}
					}
				}

				// set uid
				if v, ok := claims["uid"]; ok {
					switch t := v.(type) {
					case float64:
						c.Set("uid", uint(t))
					case int64:
						c.Set("uid", uint(t))
					case int:
						c.Set("uid", uint(t))
					case string:
						// ถ้าโทเคนเซ็น uid เป็น string ก็เก็บ string ไว้ (handler ต้องรองรับ)
						c.Set("uid", t)
					default:
						c.Set("uid", v)
					}
				}

				// set role
				if role, ok := claims["role"]; ok {
					if rs, ok := role.(string); ok {
						c.Set("role", rs)
					} else {
						c.Set("role", role)
					}
				}

				// (debug) log claims
				if debug {
					c.Logger().Infof("AUTH DEBUG: ok uid=%v role=%v path=%s", c.Get("uid"), c.Get("role"), path)
				}

				return next(c)
			}

			// ถ้า claims type ไม่ใช่ MapClaims
			if debug {
				c.Logger().Warn("AUTH DEBUG: token claims is not MapClaims")
			}
			return echo.NewHTTPError(http.StatusUnauthorized, "invalid or expired jwt")
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
