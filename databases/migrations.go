package databases

import "gorm.io/gorm"

// EnsurePostgresEnums: สร้าง/อัปเดต ENUM และคอลัมน์ที่ต้องใช้ แบบ idempotent
func EnsurePostgresEnums(db *gorm.DB) error {
	// --- booking_status (ของเดิมในโปรเจกต์) ---
	if err := db.Exec(`
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'booking_status') THEN
    CREATE TYPE booking_status AS ENUM ('PENDING','CONFIRMED','CANCELLED','EXPIRED','COMPLETED');
  END IF;
END $$;
`).Error; err != nil {
		return err
	}

	// --- post_type: PROVIDE | COMMUNITY ---
	if err := db.Exec(`
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'post_type') THEN
    CREATE TYPE post_type AS ENUM ('PROVIDE','COMMUNITY');
  END IF;
END $$;
`).Error; err != nil {
		return err
	}

	// เพิ่มคอลัมน์ posts.post_type ถ้ายังไม่มี
	if err := db.Exec(`
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='posts' AND column_name='post_type'
  ) THEN
    ALTER TABLE posts ADD COLUMN post_type post_type NOT NULL DEFAULT 'PROVIDE';
  END IF;
END $$;
`).Error; err != nil {
		return err
	}

	// ดัชนีช่วยค้น (ถ้ายังไม่มี)
	if err := db.Exec(`CREATE INDEX IF NOT EXISTS idx_posts_post_type ON posts(post_type)`).Error; err != nil {
		return err
	}

	return nil
}
