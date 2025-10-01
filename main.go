package main

import (
	"fmt"
	"log"
	"os"

	"github.com/RathaTart/FoodBridge/entities"
	"github.com/RathaTart/FoodBridge/server" // ใช้ AuthMiddleware
	"github.com/RathaTart/FoodBridge/server/routes"
	"github.com/RathaTart/FoodBridge/server/bootstrap"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"

)

func buildDSN() string {
	if dsn := os.Getenv("POSTGRES_DSN"); dsn != "" {
		return dsn
	}
	host := getenv("DB_HOST", "localhost")
	port := getenv("DB_PORT", "5432")
	user := getenv("DB_USER", "admin")
	pass := getenv("DB_PASSWORD", "1234")
	name := getenv("DB_NAME", "mydb")
	ssl := getenv("DB_SSLMODE", "disable")
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

	// ----- AutoMigrate -----
	if err := db.AutoMigrate(
		&entities.User{},
		&entities.Post{},
		&entities.PostDetail{},
		&entities.Report{},
		&entities.Verification{},
		&entities.Booking{},
	); err != nil {
		log.Fatal("auto-migrate failed: ", err)
	}

	stopWorkers := bootstrap.StartBackgroundWorkers(db)
	defer stopWorkers()

	// ----- Echo -----
	e := echo.New()
	e.HideBanner = true
	e.Use(middleware.Recover())
	e.Use(middleware.Logger())
	e.Use(middleware.CORS())

	// ===== Public =====
	e.GET("/health", func(c echo.Context) error {
		app := "ok"
		dbStatus := "ok"
		if sqlDB, err := db.DB(); err != nil {
			dbStatus = "error: get sql.DB failed"
		} else if err := sqlDB.Ping(); err != nil {
			dbStatus = "error: " + err.Error()
		}
		return c.JSON(200, echo.Map{"status": "ok", "app": app, "db": dbStatus})
	})

	public := e.Group("")
	routes.RegisterUserRoutes(public, db)

	// ===== Protected (ต้องมี Token) =====.
	protected := e.Group("", server.AuthMiddleware())

	routes.RegisterUserProtectedRoutes(protected, db)
	routes.RegisterPostRoutes(protected, db)
	routes.RegisterReportRoutes(protected, db)
	routes.RegisterVerificationRoutes(protected, db)
	routes.RegisterBookingRoutes(protected, db)
	// routes.RegisterPostDetailRoutes(protected, db)
	// routes.RegisterCommentRoutes(protected, db)

	// Debug routes (optional)
	fmt.Println(">>> ROUTER SETUP: dumping routes")
	for _, r := range e.Routes() {
		fmt.Printf("[ROUTE] %-6s %-28s -> %s\n", r.Method, r.Path, r.Name)
	}

	// ----- Start -----
	port := getenv("PORT", "1323")
	e.Logger.Infof("Starting server on :%s", port)
	e.Logger.Fatal(e.Start(":" + port))
}
