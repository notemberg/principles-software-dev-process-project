package post

import (
	"github.com/RathaTart/FoodBridge/dto"
	"github.com/RathaTart/FoodBridge/entities"
)

type Repository interface {
	// Post
	CreatePost(p *entities.Post) error
	UpdatePost(p *entities.Post) error
	DeletePostHard(postID uint) error
	FindPostByID(postID uint) (*entities.Post, error)
	ListPosts(q dto.ListPostsQuery, uid uint) ([]entities.Post, int64, error)

	// PostDetail
	CreateDetail(d *entities.PostDetail) error
	UpdateDetail(d *entities.PostDetail) error
	DeleteDetail(postID, detailID uint) error
	ListDetails(postID uint) ([]entities.PostDetail, error)
	FindDetail(postID, detailID uint) (*entities.PostDetail, error)
}
