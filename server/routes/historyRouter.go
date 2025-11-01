package routes

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/RathaTart/FoodBridge/app"
	"github.com/RathaTart/FoodBridge/dto"
	"github.com/RathaTart/FoodBridge/pkg/booking"
	postpkg "github.com/RathaTart/FoodBridge/pkg/post"
	"github.com/labstack/echo/v4"
)

/* helper: ดึง uid จาก context ให้ได้เป็น int64 รองรับหลายชนิด */
func uidFromCtx(c echo.Context) (int64, error) {
	v := c.Get("uid")
	switch t := v.(type) {
	case int64:
		return t, nil
	case int:
		return int64(t), nil
	case uint:
		return int64(t), nil
	case uint64:
		return int64(t), nil
	case float64:
		return int64(t), nil
	case string:
		if t == "" {
			return 0, echo.NewHTTPError(http.StatusUnauthorized, "unauthorized")
		}
		n, err := strconv.ParseInt(t, 10, 64)
		if err != nil {
			return 0, echo.NewHTTPError(http.StatusUnauthorized, "unauthorized")
		}
		return n, nil
	default:
		return 0, echo.NewHTTPError(http.StatusUnauthorized, "unauthorized")
	}
}

func RegisterHistoryRoutes(v1 *echo.Group, d app.Deps) {
	db := d.DB

	// NOTE: ใน main คุณส่งกลุ่มที่ถูกหุ้ม JWT เข้ามาแล้ว (protected)
	me := v1.Group("/me")

	// ============= My history posts =============
	me.GET("/posts/history", func(c echo.Context) error {
		uid64, err := uidFromCtx(c)
		if err != nil {
			return err
		}
		uid := uint(uid64) // service ของ post รับเป็น uint

		// สร้าง service
		repo := postpkg.NewRepository(db)
		svc := postpkg.NewService(repo)

		// ประกอบ query
		q := dto.ListPostsQuery{}
		status := "CLOSED"
		mine := true
		q.Status = &status
		q.Mine = &mine

		if v := strings.TrimSpace(c.QueryParam("page")); v != "" {
			if n, err := strconv.Atoi(v); err == nil && n > 0 {
				// หมายเหตุ: ถ้า struct ของคุณเป็น pointer ให้ปรับเป็น &n
				q.Page = n
			}
		}
		if v := strings.TrimSpace(c.QueryParam("page_size")); v != "" {
			if n, err := strconv.Atoi(v); err == nil && n > 0 {
				// หมายเหตุ: ถ้า struct ของคุณเป็น pointer ให้ปรับเป็น &n
				q.PageSize = n
			}
		}
		if v := strings.TrimSpace(c.QueryParam("sort")); v != "" {
			// หมายเหตุ: ถ้า struct ของคุณเป็น pointer ให้ปรับเป็น &v
			q.Sort = v
		}

		res, err := svc.List(uid, q)
		if err != nil {
			return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
		}
		return c.JSON(http.StatusOK, res)
	})

	// ============= My history bookings =============
	me.GET("/bookings/history", func(c echo.Context) error {
		uid64, err := uidFromCtx(c)
		if err != nil {
			return err
		}

		bRepo := booking.NewGormRepo(db)
		svc := booking.NewService(bRepo, booking.Config{}, nil)

		// รับ status CSV; ถ้าไม่ส่ง ใช้ default
		statuses := []string{"COMPLETED", "CANCELLED", "EXPIRED"}
		if v := strings.TrimSpace(c.QueryParam("status")); v != "" {
			parts := strings.Split(v, ",")
			statuses = statuses[:0]
			for _, p := range parts {
				if s := strings.TrimSpace(p); s != "" {
					statuses = append(statuses, s)
				}
			}
		}

		out, err := svc.List(c.Request().Context(), booking.Filter{
			ReceiverUserID: &uid64,
			Statuses:       statuses, // ต้องมีรองรับใน repository: WHERE status IN (..)
		})
		if err != nil {
			return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
		}
		return c.JSON(http.StatusOK, out)
	})

	// ===== My success stats =====
	// GET /me/stats/success
	me.GET("/stats/success", func(c echo.Context) error {
		uid64, err := uidFromCtx(c) // ใช้ helper uidFromCtx ที่ไฟล์นี้มีอยู่แล้ว
		if err != nil {
			return err
		}

		var savingBaht, providing, receiving int64

		// Saving (บาท)
		if err := db.Raw(`
        SELECT COALESCE(SUM(p.price), 0)
        FROM bookings b
        JOIN posts p USING (post_id)
        WHERE b.receiver_user_id = ? AND b.status = 'COMPLETED'
    `, uid64).Scan(&savingBaht).Error; err != nil {
			return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
		}

		// Providing (ครั้ง) — เจ้าของโพสต์คือ provider_id
		if err := db.Raw(`
        SELECT COUNT(*)
        FROM bookings b
        JOIN posts p USING (post_id)
        WHERE p.provider_id = ? AND b.status = 'COMPLETED'
    `, uid64).Scan(&providing).Error; err != nil {
			return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
		}

		// Receiving (ครั้ง)
		if err := db.Raw(`
        SELECT COUNT(*)
        FROM bookings b
        WHERE b.receiver_user_id = ? AND b.status = 'COMPLETED'
    `, uid64).Scan(&receiving).Error; err != nil {
			return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
		}

		return c.JSON(http.StatusOK, echo.Map{
			"saving_baht":     savingBaht,
			"providing_count": providing,
			"receiving_count": receiving,
		})
	})

}
