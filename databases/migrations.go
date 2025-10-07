package databases

import "gorm.io/gorm"

// รันซ้ำได้ (idempotent) — สร้าง ENUM ที่จำเป็นให้ Postgres
func EnsurePostgresEnums(db *gorm.DB) error {
	sql := `
DO $$
BEGIN
	IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'booking_status') THEN
		CREATE TYPE booking_status AS ENUM ('QUEUED','PENDING','CONFIRMED','CANCELLED','EXPIRED','COMPLETED');
	END IF;
END $$;
`
	return db.Exec(sql).Error
}
