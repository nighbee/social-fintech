package profile

import (
	"context"
	"mime/multipart"
	"strings"
	"time"

	"github.com/google/uuid"
	"go.uber.org/zap"
)

type Service interface {
	GetProfile(ctx context.Context, username string, viewerUserID *string) (*ProfileResponse, error)
	GetProfileByUserID(ctx context.Context, userID string, viewerUserID *string) (*ProfileResponse, error)
	UpdateProfile(ctx context.Context, userID string, req *UpdateProfileRequest) (*ProfileResponse, error)
	UpdateAvatar(ctx context.Context, userID string, file multipart.File, header *multipart.FileHeader) (string, error)
	DeleteProfile(ctx context.Context, userID string) error

	SearchProfiles(ctx context.Context, query string, limit, offset int, viewerUserID *string) ([]*ProfileResponse, int, error)
	GetNearbyProfiles(ctx context.Context, lat, lon float64, radiusKm int, limit, offset int, viewerUserID *string) ([]*ProfileResponse, int, error)

	CreateRelationship(ctx context.Context, userID string, req *CreateRelationshipRequest) error
	RemoveRelationship(ctx context.Context, userID string, req *RemoveRelationshipRequest) error
	GetAllies(ctx context.Context, userID string, limit, offset int) (*AlliesListResponse, error)
	GetFavorites(ctx context.Context, userID string, limit, offset int) (*FavoritesListResponse, error)
	CheckRelationship(ctx context.Context, userID, targetUserID string) (isAlly, isFavorite, isBlocked, followsMe bool, err error)

	ReportUser(ctx context.Context, reporterUserID string, req *ReportUserRequest) (string, error)
	GetMyReports(ctx context.Context, userID string, limit, offset int) ([]*UserReport, int, error)

	UpdateProfileStats(ctx context.Context, userID string, stats *ProfileStats) error
	UpdateReputation(ctx context.Context, userID string, reputationDelta int) error

	AdminCreateProfile(ctx context.Context, userID string) error
}

type service struct {
	repo           Repository
	storageService StorageService
	economyService EconomyService
	logger         *zap.Logger
}

type StorageService interface {
	UploadAvatar(ctx context.Context, userID string, file multipart.File, header *multipart.FileHeader) (string, error)
	DeleteFile(ctx context.Context, fileURL string) error
}

type EconomyService interface {
	GetUserBalance(ctx context.Context, userID string) (silverBalance, goldBalance int64, err error)
}

func NewService(repo Repository, storageService StorageService, economyService EconomyService) Service {
	logger, _ := zap.NewProduction()
	return &service{
		repo:           repo,
		storageService: storageService,
		economyService: economyService,
		logger:         logger,
	}
}

func (s *service) GetProfile(ctx context.Context, username string, viewerUserID *string) (*ProfileResponse, error) {
	profile, err := s.repo.GetProfileByUsername(ctx, username)
	if err != nil {
		return nil, err
	}

	if err := s.checkProfileAccess(ctx, profile, viewerUserID); err != nil {
		return nil, err
	}

	return s.buildProfileResponse(ctx, profile, viewerUserID)
}

func (s *service) GetProfileByUserID(ctx context.Context, userID string, viewerUserID *string) (*ProfileResponse, error) {
	profile, err := s.repo.GetProfileByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}

	if err := s.checkProfileAccess(ctx, profile, viewerUserID); err != nil {
		return nil, err
	}

	return s.buildProfileResponse(ctx, profile, viewerUserID)
}

func (s *service) UpdateProfile(ctx context.Context, userID string, req *UpdateProfileRequest) (*ProfileResponse, error) {
	if err := s.validateUpdateRequest(req); err != nil {
		return nil, err
	}

	profile, err := s.repo.GetProfileByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}

	if req.DisplayName != nil {
		profile.DisplayName = req.DisplayName
	}
	if req.Bio != nil {
		profile.Bio = req.Bio
	}
	if req.LocationCity != nil {
		profile.LocationCity = req.LocationCity
	}
	if req.LocationCountry != nil {
		profile.LocationCountry = req.LocationCountry
	}
	if req.IsLocationPublic != nil {
		profile.IsLocationPublic = *req.IsLocationPublic
	}
	if req.IsProfilePublic != nil {
		profile.IsProfilePublic = *req.IsProfilePublic
	}

	profile.UpdatedAt = time.Now()

	if err := s.repo.UpdateProfile(ctx, profile); err != nil {
		return nil, err
	}

	return s.buildProfileResponse(ctx, profile, &userID)
}

func (s *service) UpdateAvatar(ctx context.Context, userID string, file multipart.File, header *multipart.FileHeader) (string, error) {
	profile, err := s.repo.GetProfileByUserID(ctx, userID)
	if err != nil {
		return "", err
	}

	if profile.AvatarURL != nil && *profile.AvatarURL != "" {
		if err := s.storageService.DeleteFile(ctx, *profile.AvatarURL); err != nil {
			s.logger.Warn("failed to delete old avatar", zap.Error(err))
		}
	}

	avatarURL, err := s.storageService.UploadAvatar(ctx, userID, file, header)
	if err != nil {
		return "", ErrAvatarUploadFailed
	}

	if err := s.repo.UpdateAvatarURL(ctx, userID, avatarURL); err != nil {
		s.storageService.DeleteFile(ctx, avatarURL)
		return "", err
	}

	return avatarURL, nil
}

func (s *service) DeleteProfile(ctx context.Context, userID string) error {
	profile, err := s.repo.GetProfileByUserID(ctx, userID)
	if err != nil {
		return err
	}

	if profile.AvatarURL != nil && *profile.AvatarURL != "" {
		if err := s.storageService.DeleteFile(ctx, *profile.AvatarURL); err != nil {
			s.logger.Warn("failed to delete avatar during profile deletion", zap.Error(err))
		}
	}

	return s.repo.DeleteProfile(ctx, userID)
}

func (s *service) SearchProfiles(ctx context.Context, query string, limit, offset int, viewerUserID *string) ([]*ProfileResponse, int, error) {
	if len(strings.TrimSpace(query)) < 2 {
		return nil, 0, ErrSearchQueryTooShort
	}

	profiles, total, err := s.repo.SearchProfiles(ctx, query, limit, offset)
	if err != nil {
		return nil, 0, err
	}

	responses := make([]*ProfileResponse, 0, len(profiles))
	for _, profile := range profiles {
		if err := s.checkProfileAccess(ctx, profile, viewerUserID); err != nil {
			continue
		}
		resp, err := s.buildProfileResponse(ctx, profile, viewerUserID)
		if err != nil {
			s.logger.Warn("failed to build profile response", zap.Error(err))
			continue
		}
		responses = append(responses, resp)
	}

	return responses, total, nil
}

func (s *service) GetNearbyProfiles(ctx context.Context, lat, lon float64, radiusKm int, limit, offset int, viewerUserID *string) ([]*ProfileResponse, int, error) {
	if lat < -90 || lat > 90 || lon < -180 || lon > 180 {
		return nil, 0, ErrInvalidCoordinates
	}

	profiles, total, err := s.repo.GetNearbyProfiles(ctx, lat, lon, radiusKm, limit, offset)
	if err != nil {
		return nil, 0, err
	}

	responses := make([]*ProfileResponse, 0, len(profiles))
	for _, profile := range profiles {
		if err := s.checkProfileAccess(ctx, profile, viewerUserID); err != nil {
			continue
		}
		resp, err := s.buildProfileResponse(ctx, profile, viewerUserID)
		if err != nil {
			s.logger.Warn("failed to build profile response", zap.Error(err))
			continue
		}
		responses = append(responses, resp)
	}

	return responses, total, nil
}

func (s *service) CreateRelationship(ctx context.Context, userID string, req *CreateRelationshipRequest) error {
	if !req.RelationshipType.IsValid() {
		return ErrInvalidRelationshipType
	}

	if userID == req.TargetUserID {
		return ErrCannotRelateToSelf
	}

	targetProfile, err := s.repo.GetProfileByUserID(ctx, req.TargetUserID)
	if err != nil {
		return err
	}
	_ = targetProfile

	exists, err := s.repo.CheckRelationshipExists(ctx, userID, req.TargetUserID, req.RelationshipType)
	if err != nil {
		return err
	}
	if exists {
		return NewRelationshipExistsError(string(req.RelationshipType))
	}

	isBlocked, err := s.repo.CheckRelationshipExists(ctx, req.TargetUserID, userID, RelationshipTypeBlock)
	if err != nil {
		return err
	}
	if isBlocked {
		return ErrUserBlockedBy
	}

	if req.RelationshipType == RelationshipTypeBlock || req.RelationshipType == RelationshipTypeRestrict {
		if err := s.removeConflictingRelationships(ctx, userID, req.TargetUserID); err != nil {
			return err
		}
	}

	rel := &UserRelationship{
		ID:               uuid.New().String(),
		UserID:           userID,
		TargetUserID:     req.TargetUserID,
		RelationshipType: req.RelationshipType,
		CreatedAt:        time.Now(),
	}

	return s.repo.CreateRelationship(ctx, rel)
}

func (s *service) RemoveRelationship(ctx context.Context, userID string, req *RemoveRelationshipRequest) error {
	if !req.RelationshipType.IsValid() {
		return ErrInvalidRelationshipType
	}

	return s.repo.DeleteRelationship(ctx, userID, req.TargetUserID, req.RelationshipType)
}

func (s *service) GetAllies(ctx context.Context, userID string, limit, offset int) (*AlliesListResponse, error) {
	relationships, total, err := s.repo.GetUserRelationships(ctx, userID, RelationshipTypeAlly, limit, offset)
	if err != nil {
		return nil, err
	}

	if len(relationships) == 0 {
		return &AlliesListResponse{
			Allies: []RelationshipResponse{},
			Total:  0,
		}, nil
	}

	targetUserIDs := make([]string, len(relationships))
	for i, rel := range relationships {
		targetUserIDs[i] = rel.TargetUserID
	}

	profiles, err := s.repo.GetProfilesByUserIDs(ctx, targetUserIDs)
	if err != nil {
		return nil, err
	}

	profileMap := make(map[string]*Profile)
	for _, p := range profiles {
		profileMap[p.UserID] = p
	}

	allies := make([]RelationshipResponse, 0, len(relationships))
	for _, rel := range relationships {
		profile, ok := profileMap[rel.TargetUserID]
		if !ok {
			continue
		}

		avatarURL := ""
		if profile.AvatarURL != nil {
			avatarURL = *profile.AvatarURL
		}

		allies = append(allies, RelationshipResponse{
			ID:                rel.ID,
			TargetUserID:      rel.TargetUserID,
			TargetAvatarURL:   avatarURL,
			TargetDisplayName: profile.DisplayName,
			RelationshipType:  rel.RelationshipType,
			CreatedAt:         rel.CreatedAt,
		})
	}

	return &AlliesListResponse{
		Allies: allies,
		Total:  total,
	}, nil
}

func (s *service) GetFavorites(ctx context.Context, userID string, limit, offset int) (*FavoritesListResponse, error) {
	relationships, total, err := s.repo.GetUserRelationships(ctx, userID, RelationshipTypeFavorite, limit, offset)
	if err != nil {
		return nil, err
	}

	if len(relationships) == 0 {
		return &FavoritesListResponse{
			Favorites: []RelationshipResponse{},
			Total:     0,
		}, nil
	}

	targetUserIDs := make([]string, len(relationships))
	for i, rel := range relationships {
		targetUserIDs[i] = rel.TargetUserID
	}

	profiles, err := s.repo.GetProfilesByUserIDs(ctx, targetUserIDs)
	if err != nil {
		return nil, err
	}

	profileMap := make(map[string]*Profile)
	for _, p := range profiles {
		profileMap[p.UserID] = p
	}

	favorites := make([]RelationshipResponse, 0, len(relationships))
	for _, rel := range relationships {
		profile, ok := profileMap[rel.TargetUserID]
		if !ok {
			continue
		}

		avatarURL := ""
		if profile.AvatarURL != nil {
			avatarURL = *profile.AvatarURL
		}

		favorites = append(favorites, RelationshipResponse{
			ID:                rel.ID,
			TargetUserID:      rel.TargetUserID,
			TargetAvatarURL:   avatarURL,
			TargetDisplayName: profile.DisplayName,
			RelationshipType:  rel.RelationshipType,
			CreatedAt:         rel.CreatedAt,
		})
	}

	return &FavoritesListResponse{
		Favorites: favorites,
		Total:     total,
	}, nil
}

func (s *service) CheckRelationship(ctx context.Context, userID, targetUserID string) (isAlly, isFavorite, isBlocked, followsMe bool, err error) {
	isAlly, err = s.repo.CheckRelationshipExists(ctx, userID, targetUserID, RelationshipTypeAlly)
	if err != nil {
		return false, false, false, false, err
	}

	isFavorite, err = s.repo.CheckRelationshipExists(ctx, userID, targetUserID, RelationshipTypeFavorite)
	if err != nil {
		return false, false, false, false, err
	}

	isBlocked, err = s.repo.CheckRelationshipExists(ctx, userID, targetUserID, RelationshipTypeBlock)
	if err != nil {
		return false, false, false, false, err
	}

	followsMe, err = s.repo.CheckRelationshipExists(ctx, targetUserID, userID, RelationshipTypeAlly)
	if err != nil {
		return false, false, false, false, err
	}

	return isAlly, isFavorite, isBlocked, followsMe, nil
}

func (s *service) ReportUser(ctx context.Context, reporterUserID string, req *ReportUserRequest) (string, error) {
	if !req.Reason.IsValid() {
		return "", ErrInvalidReportReason
	}

	if reporterUserID == req.ReportedUserID {
		return "", ErrCannotReportSelf
	}

	if req.Reason == ReportReasonOther && (req.Description == nil || strings.TrimSpace(*req.Description) == "") {
		return "", ErrReportDescriptionRequired
	}

	exists, err := s.repo.CheckExistingReport(ctx, reporterUserID, req.ReportedUserID)
	if err != nil {
		return "", err
	}
	if exists {
		return "", ErrReportAlreadyExists
	}

	reportedProfile, err := s.repo.GetProfileByUserID(ctx, req.ReportedUserID)
	if err != nil {
		return "", err
	}
	_ = reportedProfile

	report := &UserReport{
		ID:             uuid.New().String(),
		ReporterID:     reporterUserID,
		ReportedUserID: req.ReportedUserID,
		Reason:         req.Reason,
		Description:    req.Description,
		Status:         ReportStatusPending,
		CreatedAt:      time.Now(),
	}

	if err := s.repo.CreateReport(ctx, report); err != nil {
		return "", err
	}

	return report.ID, nil
}

func (s *service) GetMyReports(ctx context.Context, userID string, limit, offset int) ([]*UserReport, int, error) {
	return s.repo.GetReportsByReporter(ctx, userID, limit, offset)
}

func (s *service) UpdateProfileStats(ctx context.Context, userID string, stats *ProfileStats) error {
	return s.repo.UpdateProfileStats(ctx, userID, stats)
}

func (s *service) UpdateReputation(ctx context.Context, userID string, reputationDelta int) error {
	profile, err := s.repo.GetProfileByUserID(ctx, userID)
	if err != nil {
		return err
	}

	newReputation := profile.ReputationScore + reputationDelta
	if newReputation < 0 {
		newReputation = 0
	}

	newTier := s.calculateRankTier(newReputation)

	return s.repo.UpdateReputation(ctx, userID, newTier, newReputation)
}

func (s *service) AdminCreateProfile(ctx context.Context, userID string) error {
	s.logger.Info("admin_create_profile_attempt", zap.String("user_id", userID))

	exists, err := s.repo.ProfileExists(ctx, userID)
	if err != nil {
		s.logger.Error("profile_exists_check_failed", zap.String("user_id", userID), zap.Error(err))
		return err
	}
	if exists {
		s.logger.Warn("profile_already_exists", zap.String("user_id", userID))
		return ErrProfileExists
	}

	profile := &Profile{
		UserID:           userID,
		IsProfilePublic:  true,
		IsLocationPublic: false,
		ReputationScore:  0,
		CurrentRankTier:  RankTierQuartz,
		TotalPosts:       0,
		TasksCompleted:   0,
		CreatedAt:        time.Now(),
		UpdatedAt:        time.Now(),
	}

	err = s.repo.CreateProfile(ctx, profile)
	if err != nil {
		s.logger.Error("profile_creation_failed", zap.String("user_id", userID), zap.Error(err))
		return err
	}

	s.logger.Info("profile_created_successfully", zap.String("user_id", userID))
	return nil
}

func (s *service) checkProfileAccess(ctx context.Context, profile *Profile, viewerUserID *string) error {
	if profile.IsProfilePublic {
		return nil
	}

	if viewerUserID == nil {
		return ErrProfilePrivate
	}

	if *viewerUserID == profile.UserID {
		return nil
	}

	isBlocked, err := s.repo.CheckRelationshipExists(ctx, profile.UserID, *viewerUserID, RelationshipTypeBlock)
	if err != nil {
		return err
	}
	if isBlocked {
		return ErrUserBlockedBy
	}

	blockedThem, err := s.repo.CheckRelationshipExists(ctx, *viewerUserID, profile.UserID, RelationshipTypeBlock)
	if err != nil {
		return err
	}
	if blockedThem {
		return ErrUserBlocked
	}

	isAlly, err := s.repo.CheckRelationshipExists(ctx, *viewerUserID, profile.UserID, RelationshipTypeAlly)
	if err != nil {
		return err
	}
	if !isAlly {
		return ErrProfilePrivate
	}

	return nil
}

func (s *service) buildProfileResponse(ctx context.Context, profile *Profile, viewerUserID *string) (*ProfileResponse, error) {
	// Fetch user details from users table
	userDetails, err := s.repo.GetUserDetails(ctx, profile.UserID)
	if err != nil {
		s.logger.Warn("failed to fetch user details", zap.Error(err))
		// Continue with empty user details
		userDetails = &UserDetails{}
	}

	resp := &ProfileResponse{
		UserID:           profile.UserID,
		User:             *userDetails, // Populate nested user object
		DisplayName:      profile.DisplayName,
		Bio:              profile.Bio,
		IsLocationPublic: profile.IsLocationPublic,
		IsProfilePublic:  profile.IsProfilePublic,
		ReputationScore:  profile.ReputationScore,
		CurrentRankTier:  profile.CurrentRankTier,
		CreatedAt:        profile.CreatedAt,
		IsOwn:            viewerUserID != nil && *viewerUserID == profile.UserID,
		IsActiveDonor:    false,
		Stats: ProfileStats{
			TotalPosts:             profile.TotalPosts,
			TotalGoldSealsReceived: profile.TotalGoldSealsReceived,
			TotalSilverSealsGiven:  profile.TotalSilverSealsGiven,
			TasksCompleted:         profile.TasksCompleted,
			ReputationScore:        profile.ReputationScore,
		},
	}

	if profile.AvatarURL != nil {
		resp.AvatarURL = *profile.AvatarURL
	}

	if profile.CanShowLocation() {
		resp.Location = profile.GetLocationString()
	}

	if viewerUserID != nil && *viewerUserID != profile.UserID {
		isAlly, isFavorite, isBlocked, _, err := s.CheckRelationship(ctx, *viewerUserID, profile.UserID)
		if err == nil {
			resp.IsAlly = isAlly
			resp.IsFavorite = isFavorite
			resp.IsBlocked = isBlocked
		}
	}

	if s.economyService != nil {
		silver, gold, err := s.economyService.GetUserBalance(ctx, profile.UserID)
		if err == nil {
			resp.SilverSeals = &silver
			resp.GoldSeals = &gold
		}
	}

	return resp, nil
}

func (s *service) validateUpdateRequest(req *UpdateProfileRequest) error {
	if req.DisplayName != nil {
		name := strings.TrimSpace(*req.DisplayName)
		if len(name) < 2 {
			return ErrDisplayNameTooShort
		}
		if len(name) > 50 {
			return ErrDisplayNameTooLong
		}
	}

	if req.Bio != nil && len(*req.Bio) > 500 {
		return ErrInvalidBio
	}

	return nil
}

func (s *service) removeConflictingRelationships(ctx context.Context, userID, targetUserID string) error {
	s.repo.DeleteRelationship(ctx, userID, targetUserID, RelationshipTypeAlly)
	s.repo.DeleteRelationship(ctx, userID, targetUserID, RelationshipTypeFavorite)
	return nil
}

func (s *service) calculateRankTier(reputation int) string {
	switch {
	case reputation >= 10000:
		return RankTierSovereign
	case reputation >= 5000:
		return RankTierTranscendence
	case reputation >= 2500:
		return RankTierFortitude
	case reputation >= 1000:
		return RankTierAscendance
	case reputation >= 500:
		return RankTierIntegrity
	case reputation >= 100:
		return RankTierClarity
	default:
		return RankTierQuartz
	}
}
