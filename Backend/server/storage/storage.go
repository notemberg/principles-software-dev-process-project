package storage

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"time"

	"github.com/cloudinary/cloudinary-go/v2"
	"github.com/cloudinary/cloudinary-go/v2/api/uploader"
)

type UploadResult struct {
	URL       string `json:"url"`
	PublicID  string `json:"public_id,omitempty"`
	Format    string `json:"format,omitempty"`
	Width     int    `json:"width,omitempty"`
	Height    int    `json:"height,omitempty"`
	Bytes     int64  `json:"bytes,omitempty"`
}

type Uploader interface {
	UploadImage(ctx context.Context, r io.Reader, filename string, contentType string) (*UploadResult, error)
	DeleteByPublicID(ctx context.Context, publicID string) error // เผื่ออนาคตมีลบรูป
}

// ============ Cloudinary (Signed) ============
type cloudinarySigned struct {
	cld    *cloudinary.Cloudinary
	folder string
}

func NewCloudinarySigned() (Uploader, error) {
	cld, err := cloudinary.NewFromParams(
		os.Getenv("CLOUDINARY_CLOUD_NAME"),
		os.Getenv("CLOUDINARY_API_KEY"),
		os.Getenv("CLOUDINARY_API_SECRET"),
	)
	if err != nil { return nil, err }
	return &cloudinarySigned{cld: cld, folder: os.Getenv("CLOUDINARY_FOLDER")}, nil
}

func (c *cloudinarySigned) UploadImage(ctx context.Context, r io.Reader, filename string, contentType string) (*UploadResult, error) {
	up, err := c.cld.Upload.Upload(ctx, r, uploader.UploadParams{
		Folder:       c.folder,
		ResourceType: "image",
		UseFilename:  true,
		UniqueFilename: true,
		Overwrite:    false,
	})
	if err != nil { return nil, err }
	return &UploadResult{
		URL: up.SecureURL, PublicID: up.PublicID, Format: up.Format,
		Width: int(up.Width), Height: int(up.Height), Bytes: int64(up.Bytes),
	}, nil
}
func (c *cloudinarySigned) DeleteByPublicID(ctx context.Context, publicID string) error {
	_, err := c.cld.Upload.Destroy(ctx, uploader.DestroyParams{PublicID: publicID})
	return err
}

// ============ Cloudinary (Unsigned preset) ============
type cloudinaryUnsigned struct {
	cloudName string
	preset    string
	client    *http.Client
}

func NewCloudinaryUnsigned() (Uploader, error) {
	return &cloudinaryUnsigned{
		cloudName: os.Getenv("CLOUDINARY_CLOUD_NAME"),
		preset:    os.Getenv("CLOUDINARY_UPLOAD_PRESET"),
		client:    &http.Client{Timeout: 30 * time.Second},
	}, nil
}

func (c *cloudinaryUnsigned) UploadImage(ctx context.Context, r io.Reader, filename string, contentType string) (*UploadResult, error) {
	var buf bytes.Buffer
	mw := multipart.NewWriter(&buf)
	fw, _ := mw.CreateFormFile("file", filename)
	io.Copy(fw, r)
	mw.WriteField("upload_preset", c.preset)
	_ = mw.Close()

	req, _ := http.NewRequestWithContext(ctx, "POST",
		"https://api.cloudinary.com/v1_1/"+c.cloudName+"/image/upload", &buf)
	req.Header.Set("Content-Type", mw.FormDataContentType())

	resp, err := c.client.Do(req)
	if err != nil { return nil, err }
	defer resp.Body.Close()

	var out struct {
		SecureURL string `json:"secure_url"`
		PublicID  string `json:"public_id"`
		Format    string `json:"format"`
		Width     int    `json:"width"`
		Height    int    `json:"height"`
		Bytes     int64  `json:"bytes"`
		Error     any    `json:"error"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil { return nil, err }
	if resp.StatusCode >= 400 {
		return nil,  &apiErr{Status: resp.StatusCode, Body: out.Error}
	}
	return &UploadResult{
		URL: out.SecureURL, PublicID: out.PublicID, Format: out.Format,
		Width: out.Width, Height: out.Height, Bytes: out.Bytes,
	}, nil
}
func (c *cloudinaryUnsigned) DeleteByPublicID(ctx context.Context, publicID string) error {
	// Unsigned ไม่มีสิทธิ์ลบผ่าน public API — ข้ามไว้ก่อน
	return nil
}

type apiErr struct{ Status int; Body any }
func (e *apiErr) Error() string { return "cloudinary api error" }

// ============ Factory ============
func NewUploader() (Uploader, error) {
	switch os.Getenv("STORAGE_DRIVER") {
	case "cloudinary":
		return NewCloudinarySigned()
	case "cloudinary_unsigned":
		return NewCloudinaryUnsigned()
	default:
		// ถ้าต้องการยังรองรับ MinIO: คืน uploader ของ MinIO ตรงนี้
		return nil, nil
	}
}
