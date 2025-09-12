package databases

import (
	"fmt"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"github.com/RathaTart/FoodBridge/config"
	"github.com/RathaTart/FoodBridge/entities"
)

func Connect(cfg config.Config) (*gorm.DB, error) {
	dsn := fmt.Sprintf(
		"host=%s user=%s password=%s dbname=%s port=%s sslmode=%s TimeZone=Asia/Bangkok",
		cfg.DBHost, cfg.DBUser, cfg.DBPass, cfg.DBName, cfg.DBPort, cfg.DBSSL,
	)
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		return nil, err
	}

	// ตัวอย่าง AutoMigrate ตารางแรก (ค่อยเพิ่มภายหลัง)
	if err := db.AutoMigrate(&entities.User{}); err != nil {
		return nil, err
	}

	return db, nil
}
