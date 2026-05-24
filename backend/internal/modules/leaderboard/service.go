package leaderboard

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/brightbund-backend/internal/modules/ranks"
	"github.com/brightbund-backend/internal/platform/cache"
)

var ErrNoLocation = errors.New("leaderboard: user has no location set for this scope")
var ErrInvalidScope = errors.New("leaderboard: invalid scope")

type Service struct {
	repo  *Repository
	cache *cache.Cache
}

func NewService(repo *Repository, cache *cache.Cache) *Service {
	return &Service{repo: repo, cache: cache}
}

func (s *Service) GetLeaderboard(ctx context.Context, userID string, scope Scope, limit int) (*Response, error) {
	if !scope.Valid() {
		return nil, ErrInvalidScope
	}
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	year, week := time.Now().UTC().ISOWeek()

	key, err := s.buildKey(ctx, userID, scope, year, week)
	if err != nil {
		return nil, err
	}

	// Fetch top N members with their weekly scores from Redis.
	members, err := s.cache.ZRevRangeWithScores(ctx, key, 0, int64(limit-1))
	if err != nil {
		return nil, fmt.Errorf("leaderboard: redis fetch: %w", err)
	}

	if len(members) == 0 {
		return &Response{Scope: scope, Year: year, Week: week, Entries: []Entry{}}, nil
	}

	// Collect user IDs for batch DB fetch.
	userIDs := make([]string, len(members))
	for i, m := range members {
		userIDs[i] = fmt.Sprint(m.Member)
	}

	profiles, err := s.repo.getUserProfiles(ctx, userIDs)
	if err != nil {
		return nil, fmt.Errorf("leaderboard: profile fetch: %w", err)
	}

	entries := make([]Entry, 0, len(members))
	for i, m := range members {
		uid := fmt.Sprint(m.Member)
		p := profiles[uid]

		rankDef, level, _, _ := ranks.CalculateRankAndLevel(p.GoldSeals)

		entries = append(entries, Entry{
			Rank:          i + 1,
			UserID:        uid,
			Username:      p.Username,
			DisplayName:   p.DisplayName,
			AvatarURL:     p.AvatarURL,
			WeeklyScore:   int(m.Score),
			HonorScore:    p.GoldSeals,
			RankName:      rankDef.Name,
			RankLevel:     level,
			IsCurrentUser: uid == userID,
		})
	}

	return &Response{Scope: scope, Year: year, Week: week, Entries: entries}, nil
}

func (s *Service) buildKey(ctx context.Context, userID string, scope Scope, year, week int) (string, error) {
	if scope == ScopeGlobal {
		return fmt.Sprintf("leaderboard:global:week:%d:%d", year, week), nil
	}

	reg, err := s.repo.getUserRegion(ctx, userID)
	if err != nil {
		return "", fmt.Errorf("leaderboard: get region: %w", err)
	}

	switch scope {
	case ScopeDistrict:
		if reg.H3Res5 == nil {
			return "", ErrNoLocation
		}
		return fmt.Sprintf("leaderboard:arena:%s:week:%d:%d", *reg.H3Res5, year, week), nil
	case ScopeCity:
		if reg.H3Res4 == nil {
			return "", ErrNoLocation
		}
		return fmt.Sprintf("leaderboard:city:%s:week:%d:%d", *reg.H3Res4, year, week), nil
	case ScopeCountry:
		if reg.H3Res2 == nil {
			return "", ErrNoLocation
		}
		return fmt.Sprintf("leaderboard:country:%s:week:%d:%d", *reg.H3Res2, year, week), nil
	}
	return "", ErrInvalidScope
}
