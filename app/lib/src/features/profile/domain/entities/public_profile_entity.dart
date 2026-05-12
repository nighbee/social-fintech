import 'package:app/src/core/base/base_models/base_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_profile_entity.freezed.dart';
part 'public_profile_entity.g.dart';

@freezed
class PublicProfileEntity extends BaseEntity with _$PublicProfileEntity {
  const factory PublicProfileEntity({
    required String userId,
    required String displayName,
    @Default('') String username,
    required String firstName,
    required String lastName,
    required String bio,
    required String avatarUrl,
    required String country,
    required String city,
    required String region,
    required int reputationScore,
    required String rankTier,
  }) = _PublicProfileEntity;

  const factory PublicProfileEntity.empty({
    @Default('') String userId,
    @Default('') String displayName,
    @Default('') String username,
    @Default('') String firstName,
    @Default('') String lastName,
    @Default('') String bio,
    @Default('') String avatarUrl,
    @Default('') String country,
    @Default('') String city,
    @Default('') String region,
    @Default(0) int reputationScore,
    @Default('') String rankTier,
  }) = _PublicProfileEntityEmpty;

  factory PublicProfileEntity.fromJson(Map<String, dynamic> json) =>
      _$PublicProfileEntityFromJson(json);
}
