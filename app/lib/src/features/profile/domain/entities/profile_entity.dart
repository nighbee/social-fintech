import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:app/src/core/base/base_models/base_entity.dart';

part 'profile_entity.freezed.dart';
part 'profile_entity.g.dart';

@freezed
class ProfileEntity extends BaseEntity with _$ProfileEntity {
  const factory ProfileEntity({
    required String userId,
    required String displayName,
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String bio,
    required String avatarUrl,
    required String country,
    required String city,
    required bool isPublic,
    required int reputationScore,
    required String rankTier,
    // required DateTime createdAt,
    // required DateTime updatedAt,
  }) = _ProfileEntity;

  const factory ProfileEntity.empty({
    @Default('') String userId,
    @Default('') String displayName,
    @Default('') String firstName,
    @Default('') String lastName,
    @Default('') String dateOfBirth,
    @Default('') String bio,
    @Default('') String avatarUrl,
    @Default('') String country,
    @Default('') String city,
    @Default(true) bool isPublic,
    @Default(0) int reputationScore,
    @Default('') String rankTier,
    // @Default(null) DateTime? createdAt,
    // @Default(null) DateTime? updatedAt,
  }) = _ProfileEntityEmpty;

  factory ProfileEntity.fromJson(Map<String, dynamic> json) =>
      _$ProfileEntityFromJson(json);
}
