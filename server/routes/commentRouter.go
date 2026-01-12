// server/routes/commentRouter.go
package routes

import (
	"github.com/RathaTart/FoodBridge/pkg/comment"
	"github.com/labstack/echo/v4"
	"gorm.io/gorm"
)

func RegisterCommentRoutes(protected *echo.Group, db *gorm.DB) {
	// init deps
	repo := comment.NewRepository(db)
	svc  := comment.NewService(db, repo)
	ctrl := comment.NewController(svc)

	// Top-level: PATCH/DELETE /comments/:id
	comments := protected.Group("/comments")
	ctrl.RegisterTopLevel(comments)

	// Nested under posts: POST/GET /posts/:post_id/comments
	posts := protected.Group("/posts")
	ctrl.RegisterUnderPosts(posts)
}
