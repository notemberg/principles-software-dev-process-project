package routes

import (
	"bytes"
	"encoding/json"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/labstack/echo/v4"
)

func RegisterUploadRoutes(g *echo.Group) {
	me := g.Group("/me")
	me.POST("/uploads/images", uploadImageHandler)
}

// อัปโหลดรูปไป Cloudinary แบบ Unsigned preset
// ต้องมี ENV: CLOUDINARY_CLOUD_NAME, CLOUDINARY_UPLOAD_PRESET
func uploadImageHandler(c echo.Context) error {
	fh, err := c.FormFile("file")
	if err != nil {
		return c.JSON(http.StatusBadRequest, echo.Map{"message": "field 'file' is required"})
	}
	src, err := fh.Open()
	if err != nil {
		return c.JSON(http.StatusBadRequest, echo.Map{"message": err.Error()})
	}
	defer src.Close()

	cloudName := os.Getenv("CLOUDINARY_CLOUD_NAME")
	preset := os.Getenv("CLOUDINARY_UPLOAD_PRESET")
	if cloudName == "" || preset == "" {
		return c.JSON(http.StatusInternalServerError, echo.Map{
			"message": "missing CLOUDINARY_CLOUD_NAME or CLOUDINARY_UPLOAD_PRESET",
		})
	}

	// เตรียม multipart/form-data เพื่อยิงไป Cloudinary
	var buf bytes.Buffer
	mw := multipart.NewWriter(&buf)

	// แนบไฟล์
	fw, err := mw.CreateFormFile("file", filepath.Base(fh.Filename))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, echo.Map{"message": err.Error()})
	}
	if _, err := io.Copy(fw, src); err != nil {
		return c.JSON(http.StatusInternalServerError, echo.Map{"message": err.Error()})
	}

	// แนบ upload_preset
	if err := mw.WriteField("upload_preset", preset); err != nil {
		return c.JSON(http.StatusInternalServerError, echo.Map{"message": err.Error()})
	}
	_ = mw.Close()

	// ยิงไป Cloudinary
	req, _ := http.NewRequest("POST",
		"https://api.cloudinary.com/v1_1/"+cloudName+"/image/upload",
		&buf)
	req.Header.Set("Content-Type", mw.FormDataContentType())
	req.Header.Set("User-Agent", "foodbridge-be")

	httpClient := &http.Client{Timeout: 30 * time.Second}
	resp, err := httpClient.Do(req)
	if err != nil {
		return c.JSON(http.StatusBadRequest, echo.Map{"message": "cloudinary error: " + err.Error()})
	}
	defer resp.Body.Close()

	// อ่านผลลัพธ์
	var out struct {
		SecureURL string      `json:"secure_url"`
		PublicID  string      `json:"public_id"`
		Format    string      `json:"format"`
		Width     int         `json:"width"`
		Height    int         `json:"height"`
		Bytes     int64       `json:"bytes"`
		Error     interface{} `json:"error"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return c.JSON(http.StatusBadRequest, echo.Map{"message": "decode cloudinary response failed"})
	}
	if resp.StatusCode >= 400 {
		return c.JSON(resp.StatusCode, echo.Map{"message": "cloudinary upload failed", "error": out.Error})
	}

	// ส่งกลับรูปแบบที่ FE ใช้อยู่
	return c.JSON(http.StatusOK, echo.Map{
		"url":         out.SecureURL, // ใช้เป็นลิงก์รูปในโพสต์ได้ทันที
		"public_id":   out.PublicID,  // เผื่อเก็บไว้ลบ/ใช้งานต่อ
		"format":      out.Format,
		"width":       out.Width,
		"height":      out.Height,
		"bytes":       out.Bytes,
		"contentType": "image/" + out.Format,
	})
}
