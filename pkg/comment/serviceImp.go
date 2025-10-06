package comment

import (
	"context"
	"errors"

	"github.com/RathaTart/FoodBridge/dto"
	"github.com/RathaTart/FoodBridge/entities"
	"gorm.io/gorm"
)

type service struct{ db *gorm.DB; repo Repo }

func NewService(db *gorm.DB, repo Repo) Service { return &service{db: db, repo: repo} }

func toCommentResponse(pc entities.PostComment) dto.CommentResponse {
	return dto.CommentResponse{
		CommentID: pc.CommentID,
		PostID:    pc.PostID,
		UserID:    pc.UserID,
		ParentID:  pc.ParentID,
		Body:      pc.Body,
		Status:    pc.Status,
		CreatedAt: pc.CreatedAt,
		UpdatedAt: pc.UpdatedAt,
	}
}

func (s *service) Create(ctx context.Context, postID, userID uint, req dto.CreateCommentRequest) (*dto.CommentResponse, error) {
	var out dto.CommentResponse
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		r := &gormRepo{db: tx}

		// if parent provided, optionally validate it belongs to same post
		if req.ParentID != nil {
			par, err := r.FindByID(ctx, *req.ParentID)
			if err != nil { return err }
			if par.PostID != postID { return errors.New("invalid parent_id: different post") }
			if par.Status != "visible" { return errors.New("invalid parent_id: not visible") }
		}

		pc := &entities.PostComment{
			PostID:   postID,
			UserID:   userID,
			ParentID: req.ParentID,
			Body:     req.Body,
			Status:   "visible",
		}
		if err := r.Create(ctx, pc); err != nil { return err }

		// increment post counter
		if err := r.IncPostCommentCount(ctx, postID, +1); err != nil { return err }

		out = toCommentResponse(*pc)
		return nil
	})
	return &out, err
}

func (s *service) Update(ctx context.Context, commentID, userID uint, req dto.UpdateCommentRequest) (*dto.CommentResponse, error) {
	var out dto.CommentResponse
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		r := &gormRepo{db: tx}
		pc, err := r.FindByID(ctx, commentID)
		if err != nil { return err }
		// only owner can edit
		if pc.UserID != userID { return errors.New("forbidden: not owner") }
		if pc.Status != "visible" { return errors.New("cannot edit deleted comment") }

		if err := r.UpdateBody(ctx, commentID, req.Body); err != nil { return err }

		// reload to get UpdatedAt
		pc2, err := r.FindByID(ctx, commentID)
		if err != nil { return err }
		out = toCommentResponse(*pc2)
		return nil
	})
	return &out, err
}

func (s *service) Delete(ctx context.Context, commentID, userID uint) error {
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		r := &gormRepo{db: tx}

		pc, err := r.FindByID(ctx, commentID)
		if err != nil { return err }
		if pc.UserID != userID { return errors.New("forbidden: not owner") }

		postID, affected, err := r.SoftDeleteCascade(ctx, commentID)
		if err != nil { return err }

		if affected > 0 {
			if err := r.IncPostCommentCount(ctx, postID, -int(affected)); err != nil { return err }
		}
		return nil
	})
}


func (s *service) List(ctx context.Context, postID uint, parentID *uint, limit, offset int, includeChildren bool) (*dto.ListCommentsResponse, error) {
	rows, total, err := s.repo.ListByPost(ctx, postID, parentID, limit, offset)
	if err != nil { return nil, err }

	out := make([]dto.CommentResponse, 0, len(rows))
	topIDs := make([]uint, 0, len(rows))
	for _, r := range rows {
		out = append(out, toCommentResponse(r))
		if parentID == nil { topIDs = append(topIDs, r.CommentID) }
	}

	resp := &dto.ListCommentsResponse{
		PostID:   postID,
		ParentID: parentID,
		Limit:    limit,
		Offset:   offset,
		Total:    total,
		Comments: out,
		Count:    int64(len(out)),
	}
	if includeChildren && parentID == nil {
		all, err := s.repo.CountVisibleByPost(ctx, postID)
		if err != nil { return nil, err }
		resp.Total = all
	}
	// Build nested tree only when listing top-level comments
	if includeChildren && parentID == nil && len(topIDs) > 0 {
		nodes := make(map[uint]*dto.CommentNode, len(topIDs))
		tree := make([]dto.CommentNode, 0, len(topIDs))

		// seed with top-level comments (in order)
		queueParents := make([]uint, 0, len(topIDs))
		for _, c := range rows {
			n := dto.CommentNode{Comment: toCommentResponse(c)}
			tree = append(tree, n)
			nodes[c.CommentID] = &tree[len(tree)-1]
			queueParents = append(queueParents, c.CommentID)
		}

		// BFS over children
		cur := queueParents
		for len(cur) > 0 {
			children, err := (&gormRepo{db: s.db}).listChildrenByParents(ctx, postID, cur)
			if err != nil { return nil, err }

			next := make([]uint, 0)
			for _, ch := range children {
				if ch.ParentID == nil { continue }
				parentNode := nodes[*ch.ParentID]
				if parentNode == nil { continue }

				childNode := dto.CommentNode{Comment: toCommentResponse(ch)}
				parentNode.Replies = append(parentNode.Replies, childNode)

				// track pointer for deeper levels
				idx := len(parentNode.Replies) - 1
				nodes[ch.CommentID] = &parentNode.Replies[idx]
				next = append(next, ch.CommentID)
			}
			cur = next
		}

		// ✅ attach the built tree to the response
		resp.Replies = tree
	}

	return resp, nil
}


