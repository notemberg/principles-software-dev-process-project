package notification

import (
	"context"
	"encoding/json"

	"github.com/RathaTart/FoodBridge/entities"
	"gorm.io/gorm"
)

// Repo-based publisher (useful outside tx)
type Publisher struct{ r Repo }

func NewPublisher(r Repo) *Publisher { return &Publisher{r: r} }

func (p *Publisher) Notify(ctx context.Context, userID int64, typ, title, body string, data any) error {
	var jb []byte
	if data != nil {
		jb, _ = json.Marshal(data)
	}
	return p.r.Create(ctx, &entities.Notification{
		UserID: userID,
		Title:  title,
		Body:   body,
		Type:   typ,
		Data:   jb,
	})
}

// ✅ Tx-aware helper for use INSIDE an existing transaction
func NotifyTx(ctx context.Context, tx *gorm.DB, userID int64, typ, title, body string, data any) error {
	var jb []byte
	if data != nil {
		jb, _ = json.Marshal(data)
	}
	return tx.WithContext(ctx).Create(&entities.Notification{
		UserID: userID,
		Title:  title,
		Body:   body,
		Type:   typ,
		Data:   jb,
	}).Error
}
