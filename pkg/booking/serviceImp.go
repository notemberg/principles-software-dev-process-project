package booking

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"gorm.io/gorm"

	"github.com/RathaTart/FoodBridge/entities"
)

type service struct {
	repo Repo
	cfg  Config
}

func NewService(repo Repo, cfg Config) Service {
	if cfg.DailyLimit == 0 { cfg.DailyLimit = 1 }
	if cfg.HoldTTL == 0 { cfg.HoldTTL = 10 * time.Minute }
	if cfg.DayTZ == nil {
		loc, _ := time.LoadLocation("Asia/Bangkok")
		cfg.DayTZ = loc
	}
	if cfg.QRTokenTTL == 0 { cfg.QRTokenTTL = 10 * time.Minute }
	return &service{repo: repo, cfg: cfg}
}

func (s *service) dayBounds(t time.Time) (time.Time, time.Time) {
	loc := s.cfg.DayTZ
	tt := t.In(loc)
	start := time.Date(tt.Year(), tt.Month(), tt.Day(), 0, 0, 0, 0, loc)
	end := start.Add(24 * time.Hour)
	return start, end
}

func (s *service) Create(ctx context.Context, postID int64, receiverUserID int64) (*entities.Booking, error) {
    now := time.Now()
    dayStart, dayEnd := s.dayBounds(now)

    var out *entities.Booking
    err := s.repo.WithTx(ctx, func(r Repo) error {
        // (A) Owner self-book guard
        ownerID, err := r.GetPostOwnerID(ctx, postID)
        if err != nil { return err }
        if ownerID == receiverUserID {
            return fmt.Errorf("cannot_book_own_post")
        }

        // (B) Daily limit
        cnt, err := r.CountActiveTodayByUser(ctx, receiverUserID, dayStart, dayEnd)
        if err != nil { return err }
        if cnt >= int64(s.cfg.DailyLimit) {
            return fmt.Errorf("no_booking_token_left")
        }

        // (C) Try to reserve stock (safe)
        reserved, err := r.TryReserveStock(ctx, postID)
        if err != nil { return err }

        if reserved {
            exp := now.Add(s.cfg.HoldTTL)
            b := &entities.Booking{
                PostID:         postID,
                ReceiverUserID: receiverUserID,
                Status:         entities.BookingPending,
                ExpireAt:       &exp,
            }
            if err := r.CreateBooking(ctx, b); err != nil { return err }
            out = b
            return nil
        }

        // No stock → enqueue
        pos, err := r.NextQueuePos(ctx, postID)
        if err != nil { return err }
        b := &entities.Booking{
            PostID:         postID,
            ReceiverUserID: receiverUserID,
            Status:         entities.BookingQueued,
            QueuePos:       &pos,
        }
        if err := r.CreateBooking(ctx, b); err != nil { return err }
        out = b
        return nil
    })
    return out, err
}

func (s *service) Get(ctx context.Context, id int64) (*entities.Booking, error) {
	return s.repo.GetBookingByID(ctx, id, false)
}

func (s *service) List(ctx context.Context, f Filter) ([]entities.Booking, error) {
	return s.repo.ListBookings(ctx, f)
}

func (s *service) Cancel(ctx context.Context, id int64) error {
	now := time.Now()
	return s.repo.WithTx(ctx, func(r Repo) error {
		// Lock the booking row
		b, err := r.GetBookingByID(ctx, id, true)
		if err != nil { return err }

		switch b.Status {
		case entities.BookingPending:
			// Try to promote the next queued for the same post
			next, err := r.FindNextQueued(ctx, b.PostID)
			if err == nil && next != nil {
				// Promote queued → pending (no net stock change)
				exp := now.Add(s.cfg.HoldTTL)
				next.Status = entities.BookingPending
				next.ExpireAt = &exp
				next.UpdatedAt = now
				if err := r.UpdateBooking(ctx, next); err != nil { return err }
				// Do NOT return stock here; the reservation moves to 'next'
			} else {
				// No one queued → return stock (+1)
				if err2 := r.IncrementQty(ctx, b.PostID, 1); err2 != nil { return err2 }
				// If err was real other-than-not-found, bubble it up
				// (gorm.ErrRecordNotFound is fine – already handled by adding stock)
				if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) { return err }
			}

			// Finally mark the current booking as CANCELLED
			b.Status = entities.BookingCancelled
			b.UpdatedAt = now
			return r.UpdateBooking(ctx, b)

		case entities.BookingQueued:
			// Simply drop it from the queue (no stock change)
			b.Status = entities.BookingCancelled
			b.UpdatedAt = now
			return r.UpdateBooking(ctx, b)

		default:
			// Other states: allow idempotent cancel only if not already terminal?
			if b.Status == entities.BookingCancelled {
				return nil
			}
			// Completed/Expired cannot be cancelled
			return fmt.Errorf("invalid_status_transition")
		}
	})
}


func (s *service) Complete(ctx context.Context, id int64) error {
	now := time.Now()
	return s.repo.WithTx(ctx, func(r Repo) error {
		b, err := r.GetBookingByID(ctx, id, true)
		if err != nil { return err }

		if b.Status == entities.BookingExpired || b.Status == entities.BookingCancelled {
			return fmt.Errorf("invalid_status_transition")
		}
		if b.Status == entities.BookingPending && b.ExpireAt != nil && now.After(*b.ExpireAt) {
			// treat as expired
			b.Status = entities.BookingExpired
			b.ExpiredAt = &now
			b.UpdatedAt = now
			// try to promote next queued OR return stock
			if err := r.UpdateBooking(ctx, b); err != nil { return err }
			next, e2 := r.FindNextQueued(ctx, b.PostID)
			if e2 == nil && next != nil {
				exp := now.Add(s.cfg.HoldTTL)
				next.Status = entities.BookingPending
				next.ExpireAt = &exp
				next.UpdatedAt = now
				return r.UpdateBooking(ctx, next)
			}
			if errors.Is(e2, gorm.ErrRecordNotFound) {
				return r.IncrementQty(ctx, b.PostID, 1)
			}
			return e2
		}

		// normal complete
		b.Status = entities.BookingCompleted
		b.UpdatedAt = now
		return r.UpdateBooking(ctx, b)
	})
}

// ===== QR HMAC =====

func (s *service) IssueQR(ctx context.Context, id int64, ttl time.Duration) (string, error) {
	if ttl <= 0 { ttl = s.cfg.QRTokenTTL }
	exp := time.Now().Add(ttl).Unix()
	payload := fmt.Sprintf("%d:%d", id, exp)
	mac := hmac.New(sha256.New, s.cfg.QRSecret)
	mac.Write([]byte(payload))
	sig := mac.Sum(nil)
	return base64.RawURLEncoding.EncodeToString([]byte(payload)) + "." + base64.RawURLEncoding.EncodeToString(sig), nil
}

func (s *service) ScanQR(ctx context.Context, token string) (*entities.Booking, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 2 { return nil, fmt.Errorf("bad_qr") }
	raw, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil { return nil, fmt.Errorf("bad_qr") }
	sig, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil { return nil, fmt.Errorf("bad_qr") }

	mac := hmac.New(sha256.New, s.cfg.QRSecret)
	mac.Write(raw)
	if !hmac.Equal(sig, mac.Sum(nil)) {
		return nil, fmt.Errorf("bad_qr_sig")
	}

	payload := string(raw) // bookingID:exp
	colon := strings.IndexByte(payload, ':')
	if colon < 0 { return nil, fmt.Errorf("bad_qr_payload") }
	idStr := payload[:colon]
	expStr := payload[colon+1:]
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil { return nil, fmt.Errorf("bad_qr_payload") }
	exp, err := strconv.ParseInt(expStr, 10, 64)
	if err != nil { return nil, fmt.Errorf("bad_qr_payload") }
	if time.Now().Unix() > exp {
		return nil, fmt.Errorf("qr_expired")
	}
	return s.repo.GetBookingByID(ctx, id, false)
}
