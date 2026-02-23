package mapmodule

import (
	"context"
	"fmt"
	"time"

	"github.com/brightbund-backend/internal/modules/economy"
	"github.com/google/uuid"
	"github.com/uber/h3-go/v4"
)

const (
	h3ResCountry  = 2
	h3ResCity     = 4
	h3ResDistrict = 5
)

type Service struct {
	repo        Repository
	economyRepo economy.Repository
}

func NewService(repo Repository, economyRepo economy.Repository) *Service {
	return &Service{
		repo:        repo,
		economyRepo: economyRepo,
	}
}

func (s *Service) CreateTask(ctx context.Context, userID string, req *CreateTaskRequest) (*TaskResponse, error) {
	if req == nil {
		return nil, ErrInvalidTitle
	}
	if req.Title == "" || len(req.Title) > 100 {
		return nil, ErrInvalidTitle
	}
	if !isValidCoordinates(req.Latitude, req.Longitude) {
		return nil, ErrInvalidCoordinates
	}
	if req.Reward <= 0 {
		return nil, ErrInvalidReward
	}

	rewardCents := economy.SealsToCentinels(req.Reward)
	h3Res5, h3Res4, h3Res2 := computeH3Indices(req.Latitude, req.Longitude)

	tx, err := s.repo.BeginTx(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	txRepo := s.repo.WithTx(tx)
	econTxRepo := s.economyRepo.WithTx(tx)

	taskID := uuid.NewString()
	if err := economy.ChargeForTaskCreationTx(ctx, econTxRepo, userID, taskID, rewardCents); err != nil {
		return nil, err
	}

	task := &Task{
		ID:        taskID,
		Title:     req.Title,
		Reward:    rewardCents,
		CreatorID: userID,
		Latitude:  req.Latitude,
		Longitude: req.Longitude,
		IsActive:  true,
		H3Res5:    &h3Res5,
		H3Res4:    &h3Res4,
		H3Res2:    &h3Res2,
	}
	if err := txRepo.CreateTask(ctx, task); err != nil {
		return nil, err
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	return &TaskResponse{
		ID:        task.ID,
		Title:     task.Title,
		Reward:    economy.CentinelsToSeals(task.Reward),
		Latitude:  task.Latitude,
		Longitude: task.Longitude,
		CreatedAt: time.Now(),
	}, nil
}

func (s *Service) GetNearbyTasks(ctx context.Context, lat, lon, radiusMeters float64, limit int) (*NearbyTasksResponse, error) {
	if !isValidCoordinates(lat, lon) {
		return nil, ErrInvalidCoordinates
	}
	if radiusMeters <= 0 {
		radiusMeters = 2000
	}
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	tasks, err := s.repo.GetTasksNearby(ctx, lat, lon, radiusMeters, limit)
	if err != nil {
		return nil, err
	}

	resp := NearbyTasksResponse{Tasks: make([]TaskResponse, 0, len(tasks))}
	for _, t := range tasks {
		resp.Tasks = append(resp.Tasks, TaskResponse{
			ID:        t.ID,
			Title:     t.Title,
			Reward:    economy.CentinelsToSeals(t.Reward),
			Latitude:  t.Latitude,
			Longitude: t.Longitude,
			CreatedAt: t.CreatedAt,
		})
	}

	return &resp, nil
}

func (s *Service) SetUserRegion(ctx context.Context, userID string, req *RegionAssignmentRequest) (*RegionAssignmentResponse, error) {
	if req == nil {
		return nil, ErrInvalidCoordinates
	}

	if !req.LocationOptIn {
		if err := s.repo.UpdateUserRegion(ctx, userID, nil, nil, nil, false, false); err != nil {
			return nil, err
		}
		return &RegionAssignmentResponse{
			ParticipateDistrict: false,
			LocationOptIn:       false,
			UpdatedAt:           time.Now(),
		}, nil
	}

	if !isValidCoordinates(req.Latitude, req.Longitude) {
		return nil, ErrInvalidCoordinates
	}

	h3Res5, h3Res4, h3Res2 := computeH3Indices(req.Latitude, req.Longitude)
	if err := s.repo.UpdateUserRegion(ctx, userID, &h3Res5, &h3Res4, &h3Res2, req.ParticipateDistrict, true); err != nil {
		return nil, err
	}

	return &RegionAssignmentResponse{
		H3Res5:             h3Res5,
		H3Res4:             h3Res4,
		H3Res2:             h3Res2,
		ParticipateDistrict: req.ParticipateDistrict,
		LocationOptIn:      true,
		UpdatedAt:          time.Now(),
	}, nil
}

func (s *Service) GetRegionChampions(ctx context.Context, h3Indexes []string, resolution, year, week int) ([]ChampionPin, error) {
	if len(h3Indexes) == 0 {
		return []ChampionPin{}, nil
	}

	champs, err := s.repo.GetRegionChampions(ctx, h3Indexes, resolution, year, week)
	if err != nil {
		return nil, err
	}

	pins := make([]ChampionPin, 0, len(champs))
	for _, c := range champs {
		pins = append(pins, ChampionPin{
			H3Index:    c.H3Index,
			Resolution: c.Resolution,
			UserID:     c.UserID,
			Score:      c.Score,
		})
	}
	return pins, nil
}

func computeH3Indices(lat, lon float64) (string, string, string) {
	latLng := h3.LatLng{Lat: lat, Lng: lon}

	cell5 := h3.LatLngToCell(latLng, h3ResDistrict)
	cell4 := h3.LatLngToCell(latLng, h3ResCity)
	cell2 := h3.LatLngToCell(latLng, h3ResCountry)

	return cell5.String(), cell4.String(), cell2.String()
}

func isValidCoordinates(lat, lon float64) bool {
	if lat < -90 || lat > 90 {
		return false
	}
	if lon < -180 || lon > 180 {
		return false
	}
	return true
}
