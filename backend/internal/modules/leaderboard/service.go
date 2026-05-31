package leaderboard

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sort"
	"strconv"
	"time"

	"github.com/brightbund-backend/internal/modules/ranks"
	"github.com/brightbund-backend/internal/platform/cache"
)

var ErrNoLocation = errors.New("leaderboard: user has no location set for this scope")
var ErrInvalidScope = errors.New("leaderboard: invalid scope")
var ErrUserNotFound = errors.New("leaderboard: user not found")

const profileCacheTTL = 5 * time.Minute
const leaderboardKeyTTL = 30 * 24 * time.Hour

type Service struct {
	repo  *Repository
	cache *cache.Cache
}

func NewService(repo *Repository, cache *cache.Cache) *Service {
	return &Service{repo: repo, cache: cache}
}

type memberWithFirstSeen struct {
	userID    string
	score     float64
	firstSeen int64
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

	members, err := s.cache.ZRevRangeWithScores(ctx, key, 0, int64(limit-1))
	if err != nil {
		return nil, fmt.Errorf("leaderboard: redis fetch: %w", err)
	}

	userInTop := false
	allUserIDs := make(map[string]bool)
	for _, m := range members {
		uid := fmt.Sprint(m.Member)
		allUserIDs[uid] = true
		if uid == userID {
			userInTop = true
		}
	}

	currentUserScore := float64(0)
	currentUserRank := 0
	if !userInTop {
		allUserIDs[userID] = true
		revRank, err := s.cache.ZRevRank(ctx, key, userID)
		if err == nil {
			currentUserRank = int(revRank)
		}
		currentUserScore, _ = s.cache.ZScore(ctx, key, userID)
	}

	userIDList := make([]string, 0, len(allUserIDs))
	for uid := range allUserIDs {
		userIDList = append(userIDList, uid)
	}

	firstSeenKey := key + ":first_seen"
	firstSeen, _ := s.cache.HGetAll(ctx, firstSeenKey)

	memberList := make([]memberWithFirstSeen, 0, len(members))
	for _, m := range members {
		uid := fmt.Sprint(m.Member)
		fs := int64(0)
		if v, ok := firstSeen[uid]; ok {
			if ts, parseErr := strconv.ParseInt(v, 10, 64); parseErr == nil {
				fs = ts
			}
		}
		memberList = append(memberList, memberWithFirstSeen{
			userID:    uid,
			score:     m.Score,
			firstSeen: fs,
		})
	}

	sort.SliceStable(memberList, func(i, j int) bool {
		if memberList[i].score != memberList[j].score {
			return memberList[i].score > memberList[j].score
		}
		return memberList[i].firstSeen < memberList[j].firstSeen
	})

	profiles, err := s.getUserProfilesCached(ctx, userIDList)
	if err != nil {
		return nil, fmt.Errorf("leaderboard: profile fetch: %w", err)
	}

	entries := make([]Entry, 0, len(memberList)+1)
	rank := 1
	for i, m := range memberList {
		if i > 0 {
			prev := memberList[i-1]
			if m.score < prev.score {
				rank = i + 1
			} else if m.score == prev.score && m.firstSeen > prev.firstSeen {
				rank = i + 1
			}
		}

		p := profiles[m.userID]
		rankDef, level, _, _ := ranks.CalculateRankAndLevel(p.GoldSeals)

		entries = append(entries, Entry{
			Rank:          rank,
			UserID:        m.userID,
			Username:      p.Username,
			DisplayName:   p.DisplayName,
			AvatarURL:     p.AvatarURL,
			WeeklyScore:   int(m.score),
			HonorScore:    p.GoldSeals,
			RankName:      rankDef.Name,
			RankQuality:   rankDef.Quality,
			RankLevel:     level,
			IsCurrentUser: m.userID == userID,
		})
	}

	if !userInTop {
		if len(entries) > 0 {
			last := entries[len(entries)-1]
			if currentUserScore < float64(last.WeeklyScore) {
				currentUserRank++
			}
		}
		p := profiles[userID]
		rankDef, level, _, _ := ranks.CalculateRankAndLevel(p.GoldSeals)
		entries = append(entries, Entry{
			Rank:          currentUserRank + 1,
			UserID:        userID,
			Username:      p.Username,
			DisplayName:   p.DisplayName,
			AvatarURL:     p.AvatarURL,
			WeeklyScore:   int(currentUserScore),
			HonorScore:    p.GoldSeals,
			RankName:      rankDef.Name,
			RankQuality:   rankDef.Quality,
			RankLevel:     level,
			IsCurrentUser: true,
		})
	}

	return &Response{Scope: scope, Year: year, Week: week, Entries: entries}, nil
}

type MyRankResponse struct {
	Scope        Scope   `json:"scope"`
	Year         int     `json:"year"`
	Week         int     `json:"week"`
	Rank         int64   `json:"rank"`
	WeeklyScore  float64 `json:"weekly_score"`
	HonorScore   int     `json:"honor_score"`
	RankName     string  `json:"rank_name"`
	RankQuality  string  `json:"rank_quality"`
	RankLevel    string  `json:"rank_level,omitempty"`
	TotalInScope int64   `json:"total_in_scope"`
}

func (s *Service) GetMyRank(ctx context.Context, userID string, scope Scope) (*MyRankResponse, error) {
	if !scope.Valid() {
		return nil, ErrInvalidScope
	}

	year, week := time.Now().UTC().ISOWeek()

	key, err := s.buildKey(ctx, userID, scope, year, week)
	if err != nil {
		return nil, err
	}

	score, _ := s.cache.ZScore(ctx, key, userID)
	total, _ := s.cache.ZCard(ctx, key)

	firstSeenKey := key + ":first_seen"
	firstSeenData, _ := s.cache.HGetAll(ctx, firstSeenKey)
	myFirstSeen := int64(0)
	if v, ok := firstSeenData[userID]; ok {
		if ts, parseErr := strconv.ParseInt(v, 10, 64); parseErr == nil {
			myFirstSeen = ts
		}
	}

	denseRank := int64(0)
	sameScoreAndEarlier := int64(0)
	if total > 0 {
		allMembers, err := s.cache.ZRevRangeWithScores(ctx, key, 0, total-1)
		if err == nil {
			for _, m := range allMembers {
				uid := fmt.Sprint(m.Member)
				if int64(m.Score) > int64(score) {
					denseRank++
				} else if int64(m.Score) == int64(score) {
					if uid == userID {
						break
					}
					otherFirstSeen := int64(0)
					if v, ok := firstSeenData[uid]; ok {
						if ts, parseErr := strconv.ParseInt(v, 10, 64); parseErr == nil {
							otherFirstSeen = ts
						}
					}
					if otherFirstSeen < myFirstSeen || (otherFirstSeen == myFirstSeen && uid < userID) {
						sameScoreAndEarlier++
					}
				}
			}
		}
	}

	rank := denseRank + sameScoreAndEarlier + 1

	profiles, err := s.getUserProfilesCached(ctx, []string{userID})
	if err != nil {
		return nil, fmt.Errorf("leaderboard: profile fetch: %w", err)
	}

	p := profiles[userID]
	rankDef, level, _, _ := ranks.CalculateRankAndLevel(p.GoldSeals)

	return &MyRankResponse{
		Scope:        scope,
		Year:         year,
		Week:         week,
		Rank:         rank,
		WeeklyScore:  score,
		HonorScore:   p.GoldSeals,
		RankName:     rankDef.Name,
		RankQuality:  rankDef.Quality,
		RankLevel:    level,
		TotalInScope: total,
	}, nil
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

func (s *Service) getUserProfilesCached(ctx context.Context, userIDs []string) (map[string]userProfile, error) {
	if len(userIDs) == 0 {
		return map[string]userProfile{}, nil
	}

	cached := make(map[string]userProfile, len(userIDs))
	var missing []string

	for _, uid := range userIDs {
		cacheKey := fmt.Sprintf("leaderboard:profiles:%s", uid)
		raw, err := s.cache.Get(ctx, cacheKey)
		if err == nil && raw != "" {
			var p userProfile
			if json.Unmarshal([]byte(raw), &p) == nil {
				cached[uid] = p
				continue
			}
		}
		missing = append(missing, uid)
	}

	if len(missing) == 0 {
		return cached, nil
	}

	dbProfiles, err := s.repo.getUserProfiles(ctx, missing)
	if err != nil {
		return nil, err
	}

	for uid, p := range dbProfiles {
		cached[uid] = p
		data, _ := json.Marshal(p)
		cacheKey := fmt.Sprintf("leaderboard:profiles:%s", uid)
		_ = s.cache.Set(ctx, cacheKey, string(data), profileCacheTTL)
	}

	return cached, nil
}

func (s *Service) GetUserRegion(ctx context.Context, userID string) (*UserRegion, error) {
	return s.repo.getUserRegion(ctx, userID)
}

func BuildGlobalKey(year, week int) string {
	return fmt.Sprintf("leaderboard:global:week:%d:%d", year, week)
}

func BuildScopeKey(scope Scope, h3Index string, year, week int) string {
	switch scope {
	case ScopeDistrict:
		return fmt.Sprintf("leaderboard:arena:%s:week:%d:%d", h3Index, year, week)
	case ScopeCity:
		return fmt.Sprintf("leaderboard:city:%s:week:%d:%d", h3Index, year, week)
	case ScopeCountry:
		return fmt.Sprintf("leaderboard:country:%s:week:%d:%d", h3Index, year, week)
	default:
		return BuildGlobalKey(year, week)
	}
}
