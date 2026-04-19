import 'package:app/src/core/base/base_models/base_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_entity.freezed.dart';
part 'user_entity.g.dart';

@freezed
class UserEntity extends BaseEntity with _$UserEntity {
  const factory UserEntity({
    required String id,
    required String email,
    required String username,
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String avatarUrl,
    @Default('') String referralCode,
    // required DateTime createdAt,
    // required DateTime updatedAt,
  }) = _UserEntity;

  factory UserEntity.fromJson(Map<String, dynamic> json) =>
      _$UserEntityFromJson(json);
}
