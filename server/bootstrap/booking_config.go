package bootstrap

import (
    "time"
    "github.com/RathaTart/FoodBridge/pkg/booking"
)

func BookingConfig() booking.Config {
    return booking.Config{
        DailyLimit: 2,
        HoldTTL:    30 * time.Minute,
        QRTokenTTL: 30 * time.Minute,
    }
}
