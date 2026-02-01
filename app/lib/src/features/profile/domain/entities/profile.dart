import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

/// Profile entity matching backend ProfileResponse
@freezed
class Profile with _$Profile {
  const Profile._();

  const factory Profile({
    required String userId,
    required String username,
    String? displayName,
    String? firstName,
    String? lastName,
    String? avatarUrl,
    String? bio,
    String? location,
    String? locationCity,
    String? locationCountry,
    required bool isLocationPublic,
    required bool isProfilePublic,
    ProfileStats? stats,
    required String currentRankTier,
    required int reputationScore,
    int? silverSeals,
    int? goldSeals,
    required bool isActiveDonor,
    required bool isAlly,
    required bool isFavorite,
    required bool isBlocked,
    required bool isOwn,
    required DateTime createdAt,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) => _$ProfileFromJson(json);

  String get effectiveDisplayName {
    if (displayName != null && displayName!.isNotEmpty) return displayName!;
    final first = firstName ?? '';
    final last = lastName ?? '';
    final fullName = '$first $last'.trim();
    return fullName.isNotEmpty ? fullName : username;
  }
  
  bool get hasLocation => location != null && location!.isNotEmpty;
  
  bool get canShowSeals => silverSeals != null && goldSeals != null;
}

/// Profile statistics
@freezed
class ProfileStats with _$ProfileStats {
  const factory ProfileStats({
    required int totalPosts,
    required int totalGoldSealsReceived,
    required int totalSilverSealsGiven,
    required int tasksCompleted,
    required int reputationScore,
  }) = _ProfileStats;

  factory ProfileStats.fromJson(Map<String, dynamic> json) => _$ProfileStatsFromJson(json);
}

/// Relationship type enum
enum RelationshipType {
  @JsonValue('ally')
  ally,
  @JsonValue('favorite')
  favorite,
  @JsonValue('block')
  block,
  @JsonValue('restrict')
  restrict,
}

/// User relationship response
@freezed
class RelationshipResponse with _$RelationshipResponse {
  const factory RelationshipResponse({
    required String id,
    required String targetUserId,
    String? targetUsername,
    String? targetDisplayName,
    @Default('') String targetAvatarUrl,
    required RelationshipType relationshipType,
    required DateTime createdAt,
  }) = _RelationshipResponse;

  factory RelationshipResponse.fromJson(Map<String, dynamic> json) =>
      _$RelationshipResponseFromJson(json);
}

/// Report reason enum
enum ReportReason {
  @JsonValue('spam')
  spam,
  @JsonValue('harassment')
  harassment,
  @JsonValue('inappropriate')
  inappropriate,
  @JsonValue('fake_account')
  fakeAccount,
  @JsonValue('other')
  other,
}

/// Report status enum
enum ReportStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('reviewed')
  reviewed,
  @JsonValue('dismissed')
  dismissed,
  @JsonValue('actioned')
  actioned,
}

/// User report response
@freezed
class UserReport with _$UserReport {
  const factory UserReport({
    required String id,
    required String reporterId,
    required String reportedUserId,
    required ReportReason reason,
    String? description,
    required ReportStatus status,
    required DateTime createdAt,
    DateTime? reviewedAt,
    String? reviewedBy,
  }) = _UserReport;

  factory UserReport.fromJson(Map<String, dynamic> json) => _$UserReportFromJson(json);
}

/// Rank tiers matching backend
class RankTier {
  static const String quartz = 'Quartz';
  static const String clarity = 'Clarity';
  static const String integrity = 'Integrity';
  static const String ascendance = 'Ascendance';
  static const String fortitude = 'Fortitude';
  static const String transcendence = 'Transcendence';
  static const String sovereign = 'Sovereign';

  static List<String> get all => [
        quartz,
        clarity,
        integrity,
        ascendance,
        fortitude,
        transcendence,
        sovereign,
      ];

  static int getMinReputation(String tier) {
    switch (tier) {
      case sovereign:
        return 10000;
      case transcendence:
        return 5000;
      case fortitude:
        return 2500;
      case ascendance:
        return 1000;
      case integrity:
        return 500;
      case clarity:
        return 100;
      case quartz:
      default:
        return 0;
    }
  }
}
