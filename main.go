package main

import (
	"log"

	"github.com/joho/godotenv"
	"github.com/labstack/echo/v4"

	"github.com/RathaTart/FoodBridge/app"
	"github.com/RathaTart/FoodBridge/config"
	"github.com/RathaTart/FoodBridge/databases"
	"github.com/RathaTart/FoodBridge/server"
)

func main() {
	_ = godotenv.Load()

	cfg := config.Load()

	// ต่อ DB
	db, err := databases.Connect(cfg)
	if err != nil {
		log.Fatal("db connect error: ", err)
	}

	e := echo.New()
	deps := app.Deps{Cfg: cfg, DB: db}

	server.Setup(e, deps)

	addr := ":" + cfg.ServerPort
	log.Println("listening on", addr)
	log.Fatal(e.Start(addr))
}
