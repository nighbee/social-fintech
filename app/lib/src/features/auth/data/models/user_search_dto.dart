import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/auth/domain/entities/user_search_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_search_dto.freezed.dart';
part 'user_search_dto.g.dart';

@freezed
class UserSearchDto extends BaseDto with _$UserSearchDto {
  const UserSearchDto._();

  const factory UserSearchDto({
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'first_name') required String firstName,
    @JsonKey(name: 'last_name') required String lastName,
    @JsonKey(name: 'display_name') required String displayName,
    @JsonKey(name: 'avatar_url') required String avatarUrl,
  }) = _UserSearchDto;

  factory UserSearchDto.fromJson(Map<String, dynamic> json) =>
      _$UserSearchDtoFromJson(json);

  UserSearchEntity toEntity() => UserSearchEntity(
        userId: userId,
        firstName: firstName,
        lastName: lastName,
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
}
