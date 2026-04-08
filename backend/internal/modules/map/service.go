package mapmodule

import (
	"context"
	"fmt"
	"math/rand"
	"strings"
	"time"

	"github.com/brightbund-backend/internal/modules/economy"
	"github.com/brightbund-backend/internal/platform/cache"
	"github.com/google/uuid"
	"github.com/uber/h3-go/v4"
)

func init() {
	rand.Seed(time.Now().UnixNano())
}

const (
	h3ResCountry  = 2
	h3ResCity     = 4
	h3ResDistrict = 5

	taskCooldownDays  = 7
	maxWorkersNeeded  = 20
	autoShutdownHours = 24
	leaderboardTieTTL = 14 * 24 * time.Hour
)

// validRewards lists the allowed Silver Seal reward values for a task.
var validRewards = map[int]bool{1: true, 2: true, 3: true}

type Service struct {
	repo        Repository
	economyRepo economy.Repository
	cache       *cache.Cache
}

func NewService(repo Repository, economyRepo economy.Repository, cacheClient *cache.Cache) *Service {
	return &Service{
		repo:        repo,
		economyRepo: economyRepo,
		cache:       cacheClient,
	}
}

func (s *Service) ensureCreatorActivated(ctx context.Context, userID string) error {
	status, restrictionsUntil, err := s.economyRepo.GetUserActivationState(ctx, userID)
	if err != nil {
		return err
	}
	if status == "active" {
		return nil
	}
	if restrictionsUntil != nil && restrictionsUntil.Valid && restrictionsUntil.Time.After(time.Now()) {
		return ErrCooldownActive
	}
	return ErrCooldownActive
}

func (s *Service) CreateTask(ctx context.Context, userID string, req *CreateTaskRequest) (*CreateTaskResponse, error) {
	if err := s.ensureCreatorActivated(ctx, userID); err != nil {
		return nil, err
	}

	if req == nil || req.Title == "" || len(req.Title) > 100 {
		return nil, ErrInvalidTitle
	}
	if !isValidCoordinates(req.Latitude, req.Longitude) {
		return nil, ErrInvalidCoordinates
	}
	if !validRewards[req.Reward] {
		return nil, ErrInvalidReward
	}
	if req.WorkersNeeded < 1 || req.WorkersNeeded > maxWorkersNeeded {
		return nil, ErrInvalidWorkers
	}

	// 7-day cooldown check
	lastCreatedAt, err := s.repo.GetLastTaskCreatedAt(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to check task cooldown: %w", err)
	}
	if lastCreatedAt != nil {
		cooldownEnd := lastCreatedAt.Add(taskCooldownDays * 24 * time.Hour)
		if time.Now().Before(cooldownEnd) {
			return nil, ErrCooldownActive
		}
	}

	rewardCents := economy.SealsToCentinels(float64(req.Reward))
	h3Res5, h3Res4, h3Res2 := computeH3Indices(req.Latitude, req.Longitude)
	code := generateVerificationCode()

	// Always set 24h lifecycle for tasks (auto-close if no responses).
	t := time.Now().UTC().Add(autoShutdownHours * time.Hour)
	autoShutdownAt := &t

	tx, err := s.repo.BeginTx(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	txRepo := s.repo.WithTx(tx)
	econTxRepo := s.economyRepo.WithTx(tx)

	taskID := uuid.NewString()

	// Charge creator upfront; refunded via CancelTask if cancelled before any worker confirms.
	if err := economy.ChargeForTaskCreationTx(ctx, econTxRepo, userID, taskID, rewardCents); err != nil {
		return nil, err
	}

	task := &Task{
		ID:               taskID,
		Title:            req.Title,
		Description:      strPtr(req.Description),
		Reward:           rewardCents,
		CreatorID:        userID,
		Latitude:         req.Latitude,
		Longitude:        req.Longitude,
		WorkersNeeded:    req.WorkersNeeded,
		WorkersFilled:    0,
		VerificationCode: code,
		Status:           "open",
		AutoShutdownAt:   autoShutdownAt,
		IsActive:         true,
		H3Res5:           &h3Res5,
		H3Res4:           &h3Res4,
		H3Res2:           &h3Res2,
	}
	if req.Description == "" {
		task.Description = nil
	}

	if err := txRepo.CreateTask(ctx, task); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	// Trigger background resolution of H3 to human-readable location
	go func() {
		_, _ = s.ResolveH3ToLocation(context.Background(), h3Res4)
	}()

	resp := &CreateTaskResponse{
		TaskResponse: TaskResponse{
			ID:             task.ID,
			Title:          task.Title,
			Description:    task.Description,
			Reward:         economy.CentinelsToSeals(task.Reward),
			WorkersNeeded:  task.WorkersNeeded,
			WorkersFilled:  0,
			Status:         task.Status,
			AutoShutdownAt: task.AutoShutdownAt,
			Latitude:       task.Latitude,
			Longitude:      task.Longitude,
			CreatedAt:      time.Now(),
		},
		VerificationCode: code,
	}
	return resp, nil
}

// CancelTask allows the creator to cancel an open task that has no confirmed workers yet.
// The task-creation charge is refunded atomically.
func (s *Service) CancelTask(ctx context.Context, userID, taskID string) (*CancelTaskResponse, error) {
	task, err := s.repo.GetTaskByID(ctx, taskID)
	if err != nil {
		return nil, err
	}
	if task.CreatorID != userID {
		return nil, ErrNotTaskOwner
	}
	if task.Status == "cancelled" {
		return nil, ErrTaskCancelled
	}
	if task.Status == "completed" {
		return nil, ErrTaskCompleted
	}
	// workers_filled guard is enforced by the SQL in CancelTask repo method.

	tx, err := s.repo.BeginTx(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	txRepo := s.repo.WithTx(tx)
	econTxRepo := s.economyRepo.WithTx(tx)

	cancelled, err := txRepo.CancelTask(ctx, taskID, userID)
	if err != nil {
		return nil, err
	}
	if !cancelled {
		// Either already has workers or status changed concurrently.
		return nil, ErrTaskFull
	}

	if err := economy.RefundTaskCreationTx(ctx, econTxRepo, userID, taskID, task.Reward); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	return &CancelTaskResponse{TaskID: taskID, Status: "cancelled"}, nil
}

func (s *Service) GetNearbyTasks(ctx context.Context, userID string, lat, lon, radiusMeters float64, limit int) (*NearbyTasksResponse, error) {
	if !isValidCoordinates(lat, lon) {
		return nil, ErrInvalidCoordinates
	}
	if radiusMeters <= 0 {
		radiusMeters = 2000
	}
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	tasks, err := s.repo.GetTasksNearby(ctx, userID, lat, lon, radiusMeters, limit)
	if err != nil {
		return nil, err
	}
	// If strict radius yields no data, retry once with a wider discovery radius.
	if len(tasks) == 0 && radiusMeters < 10000 {
		tasks, err = s.repo.GetTasksNearby(ctx, userID, lat, lon, 10000, limit)
		if err != nil {
			return nil, err
		}
	}

	resp := NearbyTasksResponse{Tasks: make([]TaskResponse, 0, len(tasks))}
	for _, t := range tasks {
		status := t.Status
		if t.CreatorID == userID && t.VerificationCode != "" && (t.Status == "open" || t.Status == "in_progress") {
			// Backward-compatible creator marker used by current Flutter UI.
			status = fmt.Sprintf("mine|%s", t.VerificationCode)
		}

		resp.Tasks = append(resp.Tasks, TaskResponse{
			ID:               t.ID,
			Title:            t.Title,
			Description:      t.Description,
			Reward:           economy.CentinelsToSeals(t.Reward),
			WorkersNeeded:    t.WorkersNeeded,
			WorkersFilled:    t.WorkersFilled,
			Status:           status,
			AutoShutdownAt:   t.AutoShutdownAt,
			Latitude:         t.Latitude,
			Longitude:        t.Longitude,
			CreatedAt:        t.CreatedAt,
			CreatorUsername:   t.CreatorUsername,
			CreatorAvatarURL: t.CreatorAvatarURL,
		})
	}
	return &resp, nil
}

func (s *Service) GetAppliedTasks(ctx context.Context, userID string) (*AppliedTasksResponse, error) {
	tasks, err := s.repo.GetAppliedTasks(ctx, userID)
	if err != nil {
		return nil, err
	}

	resp := AppliedTasksResponse{Tasks: make([]TaskResponse, 0, len(tasks))}
	for _, t := range tasks {
		appStatus := t.ApplicationStatus
		resp.Tasks = append(resp.Tasks, TaskResponse{
			ID:                t.ID,
			Title:             t.Title,
			Description:       t.Description,
			Reward:            economy.CentinelsToSeals(t.Reward),
			WorkersNeeded:     t.WorkersNeeded,
			WorkersFilled:     t.WorkersFilled,
			Status:            t.Status,
			AutoShutdownAt:    t.AutoShutdownAt,
			Latitude:          t.Latitude,
			Longitude:         t.Longitude,
			CreatedAt:         t.CreatedAt,
			CreatorUsername:    t.CreatorUsername,
			CreatorAvatarURL:  t.CreatorAvatarURL,
			ApplicationStatus: &appStatus,
		})
	}
	return &resp, nil
}

func (s *Service) GetMyTasks(ctx context.Context, userID string) (*AppliedTasksResponse, error) {
	tasks, err := s.repo.GetMyTasks(ctx, userID)
	if err != nil {
		return nil, err
	}

	resp := AppliedTasksResponse{Tasks: make([]TaskResponse, 0, len(tasks))}
	for _, t := range tasks {
		status := t.Status
		if t.VerificationCode != "" && (t.Status == "open" || t.Status == "in_progress") {
			// Backward-compatible creator marker used by current Flutter UI.
			status = fmt.Sprintf("mine|%s", t.VerificationCode)
		}
		resp.Tasks = append(resp.Tasks, TaskResponse{
			ID:             t.ID,
			Title:          t.Title,
			Description:    t.Description,
			Reward:         economy.CentinelsToSeals(t.Reward),
			WorkersNeeded:  t.WorkersNeeded,
			WorkersFilled:  t.WorkersFilled,
			Status:         status,
			AutoShutdownAt: t.AutoShutdownAt,
			Latitude:       t.Latitude,
			Longitude:      t.Longitude,
			CreatedAt:      t.CreatedAt,
		})
	}
	return &resp, nil
}

func (s *Service) GetTask(ctx context.Context, taskID string) (*TaskResponse, error) {
	t, err := s.repo.GetTaskByID(ctx, taskID)
	if err != nil {
		return nil, err
	}
	return &TaskResponse{
		ID:             t.ID,
		Title:          t.Title,
		Description:    t.Description,
		Reward:         economy.CentinelsToSeals(t.Reward),
		WorkersNeeded:  t.WorkersNeeded,
		WorkersFilled:  t.WorkersFilled,
		Status:         t.Status,
		AutoShutdownAt: t.AutoShutdownAt,
		Latitude:       t.Latitude,
		Longitude:      t.Longitude,
		CreatedAt:      t.CreatedAt,
	}, nil
}

// ApplyToTask is called when user2 presses "I can help" on a task pin.
// Creates a pending TaskApplication and (stub) opens a direct chat between the parties.
func (s *Service) ApplyToTask(ctx context.Context, userID, taskID string) (*ApplyToTaskResponse, error) {
	task, err := s.repo.GetTaskByID(ctx, taskID)
	if err != nil {
		return nil, err
	}
	if task.CreatorID == userID {
		return nil, ErrSelfComplete
	}
	if task.Status != "open" {
		if task.Status == "cancelled" {
			return nil, ErrTaskCancelled
		}
		if task.Status == "completed" {
			return nil, ErrTaskCompleted
		}
		return nil, ErrTaskFull
	}
	if task.WorkersFilled >= task.WorkersNeeded {
		return nil, ErrTaskFull
	}

	// Check for existing non-rejected application.
	existingApps, err := s.repo.GetApplicationsByTaskID(ctx, taskID)
	if err != nil {
		return nil, fmt.Errorf("failed to check existing applications: %w", err)
	}
	for _, a := range existingApps {
		if a.ApplicantID == userID && a.Status != "rejected" {
			return nil, ErrAlreadyApplied
		}
	}

	app := &TaskApplication{
		ID:          uuid.NewString(),
		TaskID:      taskID,
		ApplicantID: userID,
		Status:      "pending",
	}
	if err := s.repo.CreateTaskApplication(ctx, app); err != nil {
		return nil, err
	}

	// TODO(Phase 6): Open a direct chat between task.CreatorID and userID scoped to taskID.
	// call: s.chatService.OpenTaskChat(ctx, task.CreatorID, userID, taskID)

	return &ApplyToTaskResponse{
		ApplicationID: app.ID,
		TaskID:        taskID,
		Status:        "pending",
	}, nil
}

// SubmitVerificationCode is called by the helper (user2) after receiving the
// 4-digit code from the task creator in their chat.
func (s *Service) SubmitVerificationCode(ctx context.Context, userID, taskID, applicationID, code string) (*VerifyCodeResponse, error) {
	app, err := s.repo.GetApplicationByID(ctx, applicationID)
	if err != nil {
		return nil, err
	}
	if app.TaskID != taskID {
		return nil, ErrApplicationNotFound
	}
	if app.ApplicantID != userID {
		return nil, ErrNotApplicant
	}
	if app.Status == "pending" || app.Status == "rejected" {
		return nil, fmt.Errorf("application must be accepted by the creator first")
	}
	if app.Status == "code_verified" || app.Status == "confirmed" {
		return nil, ErrAlreadyVerified
	}
	if app.Status != "accepted" {
		return nil, ErrNotApplicant
	}

	task, err := s.repo.GetTaskByID(ctx, taskID)
	if err != nil {
		return nil, err
	}
	if task.VerificationCode != code {
		return nil, ErrInvalidCode
	}

	updated, err := s.repo.MarkApplicationCodeVerified(ctx, applicationID)
	if err != nil {
		return nil, err
	}
	if !updated {
		return nil, ErrAlreadyVerified
	}

	return &VerifyCodeResponse{
		ApplicationID: applicationID,
		Status:        "code_verified",
	}, nil
}

// AcceptApplication is called by the creator to accept a pending application.
func (s *Service) AcceptApplication(ctx context.Context, userID, taskID, applicationID string) error {
	task, err := s.repo.GetTaskByID(ctx, taskID)
	if err != nil {
		return err
	}
	if task.CreatorID != userID {
		return ErrNotTaskOwner
	}

	app, err := s.repo.GetApplicationByID(ctx, applicationID)
	if err != nil {
		return err
	}
	if app.TaskID != taskID {
		return ErrApplicationNotFound
	}

	// Fetch all applications to determine how many are already accepted/verified/confirmed
	apps, err := s.repo.GetApplicationsByTaskID(ctx, taskID)
	if err != nil {
		return err
	}

	acceptedCount := 0
	for _, a := range apps {
		if a.Status == "accepted" || a.Status == "code_verified" || a.Status == "confirmed" {
			acceptedCount++
		}
	}

	if acceptedCount >= task.WorkersNeeded {
		return ErrTaskFull
	}

	updated, err := s.repo.MarkApplicationAccepted(ctx, applicationID)
	if err != nil {
		return err
	}
	if !updated {
		return fmt.Errorf("application is not pending")
	}
	return nil
}

// RejectApplication is called by the creator to reject a pending application.
func (s *Service) RejectApplication(ctx context.Context, userID, taskID, applicationID string) error {
	task, err := s.repo.GetTaskByID(ctx, taskID)
	if err != nil {
		return err
	}
	if task.CreatorID != userID {
		return ErrNotTaskOwner
	}

	app, err := s.repo.GetApplicationByID(ctx, applicationID)
	if err != nil {
		return err
	}
	if app.TaskID != taskID {
		return ErrApplicationNotFound
	}

	updated, err := s.repo.MarkApplicationRejected(ctx, applicationID)
	if err != nil {
		return err
	}
	if !updated {
		return fmt.Errorf("application is not pending")
	}
	return nil
}

// WithdrawApplication is called by the executor to cancel/withdraw their own pending application.
// Physically deletes the application from the database.
func (s *Service) WithdrawApplication(ctx context.Context, userID, taskID, applicationID string) error {
	app, err := s.repo.GetApplicationByID(ctx, applicationID)
	if err != nil {
		return err
	}
	if app.TaskID != taskID {
		return ErrApplicationNotFound
	}

	// Verify the caller is the applicant
	if app.ApplicantID != userID {
		return ErrNotApplicant
	}

	// Only allow withdrawal if not confirmed. Even accepted applications can be withdrawn.
	if app.Status == "code_verified" || app.Status == "confirmed" {
		return fmt.Errorf("cannot withdraw after code verified or confirmed")
	}

	deleted, err := s.repo.DeleteApplication(ctx, applicationID)
	if err != nil {
		return err
	}
	if !deleted {
		// Just in case it was deleted concurrently
		return ErrApplicationNotFound
	}
	return nil
}

// ConfirmCompletion is triggered when user1 presses "Yes, this person helped me"
// in the confirmation popup. Transfers silver to the helper and closes the task
// when all required workers have been confirmed.
func (s *Service) ConfirmCompletion(ctx context.Context, userID, taskID, applicationID string) (*ConfirmCompletionResponse, error) {
	task, err := s.repo.GetTaskByID(ctx, taskID)
	if err != nil {
		return nil, err
	}
	if task.CreatorID != userID {
		return nil, ErrNotTaskOwner
	}
	if task.Status == "completed" {
		return nil, ErrTaskCompleted
	}
	if task.Status == "cancelled" {
		return nil, ErrTaskCancelled
	}

	app, err := s.repo.GetApplicationByID(ctx, applicationID)
	if err != nil {
		return nil, err
	}
	if app.TaskID != taskID {
		return nil, ErrApplicationNotFound
	}
	if app.Status != "code_verified" {
		return nil, ErrNotConfirmable
	}

	tx, err := s.repo.BeginTx(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	txRepo := s.repo.WithTx(tx)
	econTxRepo := s.economyRepo.WithTx(tx)

	confirmed, err := txRepo.MarkApplicationConfirmed(ctx, applicationID)
	if err != nil {
		return nil, err
	}
	if !confirmed {
		return nil, ErrNotConfirmable
	}

	if err := economy.RewardForApplicationConfirmationTx(
		ctx, econTxRepo, app.ApplicantID, taskID, applicationID, task.Reward,
	); err != nil {
		return nil, err
	}

	if err := txRepo.IncrementWorkersFilled(ctx, taskID); err != nil {
		return nil, err
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	// Derive new task status without a second DB read.
	newWorkersFilled := task.WorkersFilled + 1
	taskStatus := "in_progress"
	if newWorkersFilled >= task.WorkersNeeded {
		taskStatus = "completed"
	}

	// Update leaderboards for the helper (fire-and-forget).
	s.updateLeaderboards(app.ApplicantID, task)

	return &ConfirmCompletionResponse{
		TaskID:        taskID,
		ApplicationID: applicationID,
		Reward:        economy.CentinelsToSeals(task.Reward),
		TaskStatus:    taskStatus,
	}, nil
}

// GetTaskApplications returns all applications for a task. Creator-only.
func (s *Service) GetTaskApplications(ctx context.Context, userID, taskID string) ([]ApplicationResponse, error) {
	task, err := s.repo.GetTaskByID(ctx, taskID)
	if err != nil {
		return nil, err
	}
	if task.CreatorID != userID {
		return nil, ErrNotTaskOwner
	}

	apps, err := s.repo.GetApplicationsByTaskID(ctx, taskID)
	if err != nil {
		return nil, err
	}

	out := make([]ApplicationResponse, 0, len(apps))
	for _, a := range apps {
		out = append(out, ApplicationResponse{
			ID:                 a.ID,
			TaskID:             a.TaskID,
			ApplicantID:        a.ApplicantID,
			ApplicantUsername:  a.ApplicantUsername,
			ApplicantAvatarURL: a.ApplicantAvatarURL,
			Status:             a.Status,
			CreatedAt:          a.CreatedAt,
		})
	}
	return out, nil
}

// GetApplication returns a single application by ID.
// Accessible by the task creator or the applicant.
func (s *Service) GetApplication(ctx context.Context, userID, taskID, applicationID string) (*ApplicationResponse, error) {
	task, err := s.repo.GetTaskByID(ctx, taskID)
	if err != nil {
		return nil, err
	}

	app, err := s.repo.GetApplicationByID(ctx, applicationID)
	if err != nil {
		return nil, err
	}
	if app.TaskID != taskID {
		return nil, ErrApplicationNotFound
	}
	if task.CreatorID != userID && app.ApplicantID != userID {
		return nil, ErrNotTaskOwner
	}

	// Fetch applicant username/avatar via a single-row query.
	enriched, err := s.repo.GetEnrichedApplicationByID(ctx, applicationID)
	if err != nil {
		return nil, err
	}

	return &ApplicationResponse{
		ID:                 enriched.ID,
		TaskID:             enriched.TaskID,
		ApplicantID:        enriched.ApplicantID,
		ApplicantUsername:  enriched.ApplicantUsername,
		ApplicantAvatarURL: enriched.ApplicantAvatarURL,
		Status:             enriched.Status,
		CreatedAt:          enriched.CreatedAt,
	}, nil
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

	prev, err := s.repo.GetUserRegionState(ctx, userID)
	if err != nil {
		return nil, err
	}
	// Stabilize district/city assignment within the same ISO week when country is unchanged.
	// This prevents ranking "jumps" for users on border zones while keeping country moves immediate.
	if shouldKeepWeeklyRegion(prev, h3Res5, h3Res4, h3Res2, time.Now().UTC()) {
		if prev != nil {
			if prev.H3Res5 != nil && *prev.H3Res5 != "" {
				h3Res5 = *prev.H3Res5
			}
			if prev.H3Res4 != nil && *prev.H3Res4 != "" {
				h3Res4 = *prev.H3Res4
			}
		}
	}
	if err := s.repo.UpdateUserRegion(ctx, userID, &h3Res5, &h3Res4, &h3Res2, req.ParticipateDistrict, true); err != nil {
		return nil, err
	}

	// Trigger background resolution of H3 to human-readable location
	go func() {
		_, _ = s.ResolveH3ToLocation(context.Background(), h3Res4)
	}()

	return &RegionAssignmentResponse{
		H3Res5:              h3Res5,
		H3Res4:              h3Res4,
		H3Res2:              h3Res2,
		ParticipateDistrict: req.ParticipateDistrict,
		LocationOptIn:       true,
		UpdatedAt:           time.Now(),
	}, nil
}

func shouldKeepWeeklyRegion(prev *UserRegionState, nextRes5, nextRes4, nextRes2 string, now time.Time) bool {
	if prev == nil || prev.LocationUpdatedAt == nil || prev.H3Res5 == nil || prev.H3Res2 == nil {
		return false
	}
	prevRes5 := *prev.H3Res5
	prevRes2 := *prev.H3Res2
	if prevRes5 == "" || prevRes2 == "" {
		return false
	}
	if prevRes5 == nextRes5 {
		return false
	}
	// Country changed -> switch immediately.
	if prevRes2 != nextRes2 {
		return false
	}

	prevYear, prevWeek := prev.LocationUpdatedAt.UTC().ISOWeek()
	currYear, currWeek := now.UTC().ISOWeek()
	return prevYear == currYear && prevWeek == currWeek
}

// CompleteTask is the legacy single-actor completion path. Deprecated.
func (s *Service) CompleteTask(ctx context.Context, userID, taskID string) (*TaskCompletionResponse, error) {
	if taskID == "" {
		return nil, ErrTaskNotFound
	}

	tx, err := s.repo.BeginTx(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	txRepo := s.repo.WithTx(tx)
	econTxRepo := s.economyRepo.WithTx(tx)

	task, err := txRepo.GetTaskByID(ctx, taskID)
	if err != nil {
		return nil, err
	}
	if !task.IsActive {
		return nil, ErrTaskCompleted
	}
	if task.CreatorID == userID {
		return nil, ErrSelfComplete
	}

	updated, err := txRepo.MarkTaskCompleted(ctx, taskID, userID)
	if err != nil {
		return nil, err
	}
	if !updated {
		return nil, ErrTaskCompleted
	}

	if err := economy.RewardForTaskCompletionTx(ctx, econTxRepo, userID, taskID, task.Reward); err != nil {
		return nil, err
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	s.updateLeaderboards(userID, task)

	return &TaskCompletionResponse{
		TaskID:    taskID,
		Reward:    economy.CentinelsToSeals(task.Reward),
		Completed: true,
	}, nil
}

func (s *Service) updateLeaderboards(userID string, task *Task) {
	if s.cache == nil || task == nil {
		return
	}

	now := time.Now().UTC()
	year, week := now.ISOWeek()
	score := economy.CentinelsToSeals(task.Reward)

	if task.H3Res5 != nil && *task.H3Res5 != "" {
		key := fmt.Sprintf("leaderboard:arena:%s:week:%d:%d", *task.H3Res5, year, week)
		s.recordLeaderboardScore(key, userID, score, now)
	}
	if task.H3Res4 != nil && *task.H3Res4 != "" {
		key := fmt.Sprintf("leaderboard:city:%s:week:%d:%d", *task.H3Res4, year, week)
		s.recordLeaderboardScore(key, userID, score, now)
	}
	if task.H3Res2 != nil && *task.H3Res2 != "" {
		key := fmt.Sprintf("leaderboard:country:%s:week:%d:%d", *task.H3Res2, year, week)
		s.recordLeaderboardScore(key, userID, score, now)
	}

	globalKey := fmt.Sprintf("leaderboard:global:week:%d:%d", year, week)
	s.recordLeaderboardScore(globalKey, userID, score, now)
}

func (s *Service) recordLeaderboardScore(leaderboardKey, userID string, score float64, now time.Time) {
	ctx := context.Background()
	_, _ = s.cache.ZIncrBy(ctx, leaderboardKey, score, userID)

	// Business tie-break anchor: first contribution timestamp in this weekly leaderboard.
	firstSeenKey := leaderboardKey + ":first_seen"
	_, _ = s.cache.HSetNX(ctx, firstSeenKey, userID, now.Unix())
	_ = s.cache.Expire(ctx, firstSeenKey, leaderboardTieTTL)
}

func computeH3Indices(lat, lon float64) (string, string, string) {
	latLng := h3.LatLng{Lat: lat, Lng: lon}
	cell5 := h3.LatLngToCell(latLng, h3ResDistrict)
	cell4 := h3.LatLngToCell(latLng, h3ResCity)
	cell2 := h3.LatLngToCell(latLng, h3ResCountry)
	return cell5.String(), cell4.String(), cell2.String()
}

// generateVerificationCode returns a zero-padded 4-digit string (e.g. "0472").
func generateVerificationCode() string {
	return fmt.Sprintf("%04d", rand.Intn(10000)) //nolint:gosec // non-cryptographic code is acceptable here
}

// strPtr returns a pointer to s, or nil if s is empty.
func strPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func isValidCoordinates(lat, lon float64) bool {
	return lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
}

func (s *Service) GetRegionChampions(ctx context.Context, h3Indexes []string, resolution, year, week int) ([]ChampionPin, error) {
	if len(h3Indexes) == 0 {
		return nil, nil
	}
	champs, err := s.repo.GetRegionChampions(ctx, h3Indexes, resolution, year, week)
	if err != nil {
		return nil, err
	}
	if len(champs) == 0 {
		// Operational fallback: if worker snapshots are lagging, read current leaders from Redis.
		if pins := s.getLiveRegionChampionsFromCache(ctx, h3Indexes, resolution, year, week); len(pins) > 0 {
			return pins, nil
		}
	}

	pins := make([]ChampionPin, 0, len(champs))
	for _, c := range champs {
		pins = append(pins, ChampionPin{
			H3Index:    c.H3Index,
			Resolution: c.Resolution,
			UserID:     c.UserID.String(),
			Score:      c.Score,
		})
	}
	return pins, nil
}

func (s *Service) getLiveRegionChampionsFromCache(ctx context.Context, h3Indexes []string, resolution, year, week int) []ChampionPin {
	if s.cache == nil || len(h3Indexes) == 0 {
		return nil
	}

	var leaderboard string
	switch resolution {
	case h3ResDistrict:
		leaderboard = "arena"
	case h3ResCity:
		leaderboard = "city"
	case h3ResCountry:
		leaderboard = "country"
	default:
		return nil
	}

	pins := make([]ChampionPin, 0, len(h3Indexes))
	for _, h3Index := range h3Indexes {
		if h3Index == "" {
			continue
		}

		key := fmt.Sprintf("leaderboard:%s:%s:week:%d:%d", leaderboard, h3Index, year, week)
		members, err := s.cache.ZRevRange(ctx, key, 0, 0)
		if err != nil || len(members) == 0 {
			continue
		}

		score, err := s.cache.ZScore(ctx, key, members[0])
		if err != nil {
			continue
		}

		pins = append(pins, ChampionPin{
			H3Index:    h3Index,
			Resolution: resolution,
			UserID:     members[0],
			Score:      int64(score),
		})
	}

	return pins
}

func (s *Service) ResolveH3ToLocation(ctx context.Context, h3Index string) (*H3GeoMetadata, error) {
	// 1. Try cache
	metadata, err := s.repo.GetH3GeoMetadata(ctx, h3Index)
	if err != nil {
		return nil, err
	}
	if metadata != nil {
		return metadata, nil
	}

	// 2. Primary strategy: executable 50%+ overlap rule using the full H3 polygon
	hexWKT, err := boundaryWKTOfH3(h3Index)
	if err == nil {
		metadata, err = s.repo.GetAdministrativeHierarchyByHex(ctx, hexWKT)
		if err != nil {
			return nil, err
		}
	}

	// 3. Deterministic fallback: center-point lookup for sparse/incomplete boundaries
	if metadata == nil || (metadata.CityName == "" && metadata.RegionName == "" && metadata.CountryName == "") {
		lat, lon := centerOfH3(h3Index)
		metadata, err = s.repo.GetAdministrativeHierarchy(ctx, lat, lon)
		if err != nil {
			return nil, err
		}
	}

	// SAFETY GUARD: If metadata is still nil after both lookups, return safe default
	// This prevents "nil pointer dereference" panics in rare edge cases where:
	// - No administrative boundaries cover this H3 cell
	// - Sparse/incomplete boundary data in region
	// See: https://github.com/brightbund-backend/issues/XXX-geo-nil-metadata
	if metadata == nil {
		metadata = &H3GeoMetadata{
			H3Index:     h3Index,
			CityName:    "",
			RegionName:  "",
			CountryName: "",
			CountryCode: "",
		}
	}

	metadata.H3Index = h3Index

	// 4. Update cache
	if err := s.repo.UpsertH3GeoMetadata(ctx, metadata); err != nil {
		return nil, err
	}

	return metadata, nil
}

func centerOfH3(h3Index string) (float64, float64) {
	// h3 library: Cell is a uint64 type
	// Parse hex string to uint64, then convert to Cell type
	var cellUint uint64
	fmt.Sscanf(h3Index, "%x", &cellUint)
	cell := h3.Cell(cellUint)

	latLng := h3.CellToLatLng(cell)
	return latLng.Lat, latLng.Lng
}

func boundaryWKTOfH3(h3Index string) (string, error) {
	var cellUint uint64
	if _, err := fmt.Sscanf(h3Index, "%x", &cellUint); err != nil {
		return "", err
	}

	cell := h3.Cell(cellUint)
	boundary := h3.CellToBoundary(cell)
	if len(boundary) == 0 {
		return "", fmt.Errorf("invalid h3 boundary")
	}

	coords := make([]string, 0, len(boundary)+1)
	for _, point := range boundary {
		coords = append(coords, fmt.Sprintf("%f %f", point.Lng, point.Lat))
	}
	coords = append(coords, fmt.Sprintf("%f %f", boundary[0].Lng, boundary[0].Lat))

	return fmt.Sprintf("POLYGON((%s))", strings.Join(coords, ", ")), nil
}
