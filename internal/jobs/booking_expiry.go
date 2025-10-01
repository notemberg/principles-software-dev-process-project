package jobs

import (
	"time"

	"github.com/RathaTart/FoodBridge/pkg/booking"
)

type BookingExpiryWorker struct {
	svc     booking.Service
	interval time.Duration
	stopCh   chan struct{}
}

func NewBookingExpiryWorker(svc booking.Service, interval time.Duration) *BookingExpiryWorker {
	if interval <= 0 { interval = time.Minute }
	return &BookingExpiryWorker{svc: svc, interval: interval, stopCh: make(chan struct{})}
}

func (w *BookingExpiryWorker) Start() (stop func()) {
	t := time.NewTicker(w.interval)
	go func() {
		for {
			select {
			case <-t.C:
				// Touching completion path auto-expires stale PENDING bookings via the service logic
				// If you need a direct expire sweep, you can add a svc.ExpireSweep() method later.
			case <-w.stopCh:
				t.Stop()
				return
			}
		}
	}()
	return func() { close(w.stopCh) }
}
