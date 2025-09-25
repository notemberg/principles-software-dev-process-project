package booking

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/RathaTart/FoodBridge/entities"
)

type service struct {
	repo Repo
	cfg  Config
}

func NewService(repo Repo, cfg Config) Service {
	if cfg.HoldTTL == 0     { cfg.HoldTTL = 15 * time.Minute }
	if cfg.QRTokenTTL == 0  { cfg.QRTokenTTL = 15 * time.Minute }
	if cfg.QRSecret == nil  { cfg.QRSecret = []byte("devsecret") }
	return &service{repo: repo, cfg: cfg}
}

func (s *service) Create(ctx context.Context, postID, receiverUserID int64) (*entities.Booking, error) {
	var out *entities.Booking
	err := s.repo.WithTx(ctx, func(r Repo) error {
		stock, err := r.LockPostDetail(ctx, postID)
		if err != nil { return err }
		if stock.QtyAvailable <= 0 { return errors.New("out_of_stock") }
		if err := r.DecrementQty(ctx, postID, 1); err != nil { return err }

		now := time.Now()
		exp := now.Add(s.cfg.HoldTTL)
		b := &entities.Booking{
			PostID:         postID,
			ReceiverUserID: receiverUserID,
			Status:         entities.BookingPending,
			CreatedAt:      now,
			ExpireAt:       &exp,
		}
		if err := r.CreateBooking(ctx, b); err != nil { return err }
		out = b
		return nil
	})
	return out, err
}

func (s *service) Get(ctx context.Context, bookingID int64) (*entities.Booking, error) {
	return s.repo.GetBookingByID(ctx, bookingID, false)
}

func (s *service) List(ctx context.Context, f Filter) ([]entities.Booking, error) {
	return s.repo.ListBookings(ctx, f)
}

func (s *service) UpdateStatus(ctx context.Context, bookingID int64, newStatus entities.BookingStatus) (*entities.Booking, error) {
	var out *entities.Booking
	err := s.repo.WithTx(ctx, func(r Repo) error {
		b, err := r.GetBookingByID(ctx, bookingID, true)
		if err != nil { return err }
		if b.Status != entities.BookingPending { return errors.New("invalid_state") }

		restore := newStatus == entities.BookingCancelled || newStatus == entities.BookingExpired
		b.Status = newStatus
		b.QRToken = nil

		if err := r.UpdateBooking(ctx, b); err != nil { return err }
		if restore {
			if err := r.IncrementQty(ctx, b.PostID, 1); err != nil { return err }
		}
		out = b
		return nil
	})
	return out, err
}

func (s *service) IssueQR(ctx context.Context, bookingID int64) (string, error) {
	var token string
	err := s.repo.WithTx(ctx, func(r Repo) error {
		b, err := r.GetBookingByID(ctx, bookingID, true)
		if err != nil { return err }
		if b.Status != entities.BookingPending { return errors.New("invalid_state") }
		token = s.makeQR(bookingID, s.cfg.QRTokenTTL)
		b.QRToken = &token
		return r.UpdateBooking(ctx, b)
	})
	return token, err
}

func (s *service) ScanQR(ctx context.Context, token string) (*entities.Booking, error) {
	var out *entities.Booking
	err := s.repo.WithTx(ctx, func(r Repo) error {
		id, err := s.parseQR(token)
		if err != nil { return err }
		b, err := r.GetBookingByID(ctx, id, true)
		if err != nil { return err }
		if b.Status != entities.BookingPending { return errors.New("invalid_state") }
		b.Status = entities.BookingCompleted
		b.QRToken = nil
		if err := r.UpdateBooking(ctx, b); err != nil { return err }
		out = b
		return nil
	})
	return out, err
}

func (s *service) ExpireJob(ctx context.Context, now time.Time) error {
	f := Filter{Status: ptrStatus(entities.BookingPending), ExpiredBefore: &now}
	list, err := s.repo.ListBookings(ctx, f)
	if err != nil { return err }
	for _, b := range list {
		_, _ = s.UpdateStatus(ctx, b.BookingID, entities.BookingExpired)
	}
	return nil
}

func ptrStatus(st entities.BookingStatus) *entities.BookingStatus { return &st }

// ==== QR helpers (HMAC-SHA256; base64url(payload).base64url(sig)) =====
func (s *service) makeQR(bookingID int64, ttl time.Duration) string {
	exp := time.Now().Add(ttl).Unix()
	payload := fmt.Sprintf("%d:%d", bookingID, exp)
	sig := s.sign([]byte(payload))
	return base64.RawURLEncoding.EncodeToString([]byte(payload)) + "." + base64.RawURLEncoding.EncodeToString(sig)
}
func (s *service) parseQR(token string) (int64, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 2 { return 0, errors.New("bad_token") }
	plB, err := base64.RawURLEncoding.DecodeString(parts[0]); if err != nil { return 0, errors.New("bad_token") }
	sigB, err := base64.RawURLEncoding.DecodeString(parts[1]); if err != nil { return 0, errors.New("bad_token") }
	if !hmac.Equal(sigB, s.sign(plB)) { return 0, errors.New("bad_signature") }
	var id, exp int64
	if _, err := fmt.Sscanf(string(plB), "%d:%d", &id, &exp); err != nil { return 0, errors.New("bad_token") }
	if time.Now().Unix() > exp { return 0, errors.New("qr_expired") }
	return id, nil
}
func (s *service) sign(msg []byte) []byte {
	m := hmac.New(sha256.New, s.cfg.QRSecret); m.Write(msg); return m.Sum(nil)
}
