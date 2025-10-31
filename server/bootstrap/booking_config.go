package bootstrap

import (
	"os"
	"strconv"
	"time"

	"github.com/RathaTart/FoodBridge/pkg/booking"
)

// BookingConfig reads env and returns a shared config for all booking services.
func BookingConfig() booking.Config {
	limit := 2 // change default to 2
	if v := os.Getenv("BOOKING_DAILY_LIMIT"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 {
			limit = n
		}
	}
	loc, err := time.LoadLocation("Asia/Bangkok")
	if err != nil {
		loc = time.Local
	}
	return booking.Config{
		DailyLimit: limit,
		DayTZ:      loc,
		// optionally set HoldTTL, QRTokenTTL, QRSecret here too
	}
}