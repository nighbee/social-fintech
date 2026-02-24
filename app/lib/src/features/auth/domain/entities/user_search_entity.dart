import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_search_entity.freezed.dart';

@freezed
class UserSearchEntity with _$UserSearchEntity {
  const factory UserSearchEntity({
    required String userId,
    required String firstName,
    required String lastName,
    required String displayName,
    required String avatarUrl,
  }) = _UserSearchEntity;
}
