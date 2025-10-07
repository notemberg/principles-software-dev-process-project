package bootstrap

import (
	"log"
	"time"

	"gorm.io/gorm"

	"github.com/RathaTart/FoodBridge/internal/jobs"
	"github.com/RathaTart/FoodBridge/pkg/booking"
)

func StartBackgroundWorkers(db *gorm.DB) (stop func()) {
	repo := booking.NewGormRepo(db)

	loc, err := time.LoadLocation("Asia/Bangkok")
	if err != nil {
		log.Printf("load tz failed, fallback to local: %v", err)
		loc = time.Local
	}

	svc := booking.NewService(repo, booking.Config{
		DayTZ:      loc,
		QRSecret:   []byte("CHANGE_ME_IN_ENV"), // pass from env in your real code
		QRTokenTTL: 10 * time.Minute,
		HoldTTL:    10 * time.Minute,
	})

	stopExpiry := jobs.NewBookingExpiryWorker(svc, time.Minute).Start()

	return func() {
		if stopExpiry != nil { stopExpiry() }
	}
}
