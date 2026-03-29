import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/auth/domain/entities/user_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_dto.freezed.dart';
part 'user_dto.g.dart';

@freezed
class UserDto extends BaseDto with _$UserDto {
  const UserDto._();
  const factory UserDto({
    @JsonKey(name: 'id') required String id,
    @JsonKey(name: 'email') required String email,
    @JsonKey(name: 'username') required String username,
    @JsonKey(name: 'first_name') required String firstName,
    @JsonKey(name: 'last_name') required String lastName,
    @JsonKey(name: 'date_of_birth') String? dateOfBirth,
    @JsonKey(name: 'avatar_url') required String avatarUrl,
    @JsonKey(name: 'referral_code') @Default('') String referralCode,
    // @JsonKey(name: 'created_at') required String? createdAt,
    // @JsonKey(name: 'updated_at') required String? updatedAt,
  }) = _UserDto;

  factory UserDto.fromJson(Map<String, dynamic> json) =>
      _$UserDtoFromJson(json);

  UserEntity toEntity() => UserEntity(
    id: id,
    email: email,
    username: username,
    firstName: firstName,
    lastName: lastName,
    dateOfBirth: dateOfBirth ?? "",
    avatarUrl: avatarUrl,
    referralCode: referralCode,
    // createdAt: createdAt != null ? DateTime.tryParse(createdAt!) : null,
    // updatedAt: updatedAt != null ? DateTime.tryParse(updatedAt!) : null,
  );
}
