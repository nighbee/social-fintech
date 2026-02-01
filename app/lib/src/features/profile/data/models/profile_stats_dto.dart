import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/profile.dart';

part 'profile_stats_dto.freezed.dart';
part 'profile_stats_dto.g.dart';

@freezed
class ProfileStatsDto with _$ProfileStatsDto {
  const factory ProfileStatsDto({
    @JsonKey(name: 'total_posts') @Default(0) int totalPosts,
    @JsonKey(name: 'total_gold_seals_received') @Default(0) int totalGoldSealsReceived,
    @JsonKey(name: 'total_silver_seals_given') @Default(0) int totalSilverSealsGiven,
    @JsonKey(name: 'tasks_completed') @Default(0) int tasksCompleted,
    @JsonKey(name: 'reputation_score') @Default(0) int reputationScore,
  }) = _ProfileStatsDto;

  const ProfileStatsDto._();

  factory ProfileStatsDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileStatsDtoFromJson(json);

  ProfileStats toDomain() {
    return ProfileStats(
      totalPosts: totalPosts,
      totalGoldSealsReceived: totalGoldSealsReceived,
      totalSilverSealsGiven: totalSilverSealsGiven,
      tasksCompleted: tasksCompleted,
      reputationScore: reputationScore,
    );
  }
}
