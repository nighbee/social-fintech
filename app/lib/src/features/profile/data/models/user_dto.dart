import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/profile/domain/entities/user.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_dto.freezed.dart';
part 'user_dto.g.dart';

@freezed
class UserDto extends BaseDto with _$UserDto {
  const UserDto._();
  const factory UserDto({
    required String id,
    String? email,
    String? username,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @JsonKey(name: 'created_at') String? createdAt,
  }) = _UserDto;

  factory UserDto.fromJson(Map<String, dynamic> json) =>
      _$UserDtoFromJson(json);

  User toEntity() => User(
    id: id,
    email: email,
    username: username,
    avatarUrl: avatarUrl,
    createdAt: createdAt != null ? DateTime.tryParse(createdAt!) : null,
  );
}
