package jobs

import (
	"context"
	"log"
	"time"

	"github.com/RathaTart/FoodBridge/pkg/booking"
)

type BookingExpiryWorker struct {
	svc      booking.Service
	interval time.Duration
	stopCh   chan struct{}
}

func NewBookingExpiryWorker(svc booking.Service, interval time.Duration) *BookingExpiryWorker {
	if interval <= 0 {
		interval = time.Minute
	}
	return &BookingExpiryWorker{svc: svc, interval: interval, stopCh: make(chan struct{})}
}

func (w *BookingExpiryWorker) Start() (stop func()) {
	t := time.NewTicker(w.interval)
	go func() {
		for {
			select {
			case <-t.C:
				if err := w.svc.ExpireSweep(context.Background(), 100); err != nil {
					log.Printf("booking expiry sweep error: %v", err)
				}
			case <-w.stopCh:
				t.Stop()
				return
			}
		}
	}()
	return func() { close(w.stopCh) }
}
