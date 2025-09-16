package main

import (
	"fmt"
	"log"
	"os"

	"github.com/RathaTart/FoodBridge/entities"
	"github.com/RathaTart/FoodBridge/server/routes"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func buildDSN() string {
	// ใช้ POSTGRES_DSN ถ้ามี (รูปแบบ: host=localhost user=admin password=1234 dbname=mydb port=5432 sslmode=disable)
	if dsn := os.Getenv("POSTGRES_DSN"); dsn != "" {
		return dsn
	}
	// ไม่งั้น fallback เป็นตัวแปรย่อย (เข้ากับ docker-compose ที่คุณใช้)
	host := getenv("DB_HOST", "localhost")
	port := getenv("DB_PORT", "5432")
	user := getenv("DB_USER", "admin")
	pass := getenv("DB_PASSWORD", "1234")
	name := getenv("DB_NAME", "mydb")
	ssl  := getenv("DB_SSLMODE", "disable")
	return fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s sslmode=%s",
		host, user, pass, name, port, ssl)
}

func getenv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func main() {
	// ----- Connect DB -----
	dsn := buildDSN()
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatal("failed to connect database: ", err)
	}

	// AutoMigrate ตัวอย่าง (เพิ่ม entity อื่นๆ ตามต้องการ)
	if err := db.AutoMigrate(&entities.User{}); err != nil {
		log.Fatal("auto-migrate failed: ", err)
	}

	// ----- Echo server -----
	e := echo.New()
	e.HideBanner = true
	e.Use(middleware.Recover())
	e.Use(middleware.Logger())
	e.Use(middleware.CORS())

	// Health (APP + DB ping)
	v1 := e.Group("")

	routes.RegisterUserRoutes(v1, db)
	
	v1.GET("/health", func(c echo.Context) error {
		app := "ok"

		dbStatus := "ok"
		sqlDB, err := db.DB()
		if err != nil {
			dbStatus = "error: get sql.DB failed"
		} else if err := sqlDB.Ping(); err != nil {
			dbStatus = "error: " + err.Error()
		}

		return c.JSON(200, echo.Map{
			"status": "ok",
			"app":    app,
			"db":     dbStatus,
		})
	})

	// ----- Start server -----
	port := getenv("PORT", "1323")
	e.Logger.Infof("Starting server on :%s", port)
	e.Logger.Fatal(e.Start(":" + port))
}
