package app

import (
	"github.com/RathaTart/FoodBridge/config"
	"gorm.io/gorm"
)

type Deps struct {
	DB  *gorm.DB
	Cfg config.Config
}
