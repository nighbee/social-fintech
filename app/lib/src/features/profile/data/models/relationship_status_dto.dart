import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/profile/domain/entities/relationship_status_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'relationship_status_dto.freezed.dart';
part 'relationship_status_dto.g.dart';

@freezed
class RelationshipStatusDto extends BaseDto with _$RelationshipStatusDto {
  const RelationshipStatusDto._();
  const factory RelationshipStatusDto({
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'i_blocked_them') required bool iBlockedThem,
    @JsonKey(name: 'i_follow_them') required bool iFollowThem,
    @JsonKey(name: 'i_restricted_them') required bool iRestrictedThem,
    @JsonKey(name: 'they_follow_me') required bool theyFollowMe,
    @JsonKey(name: 'they_blocked_me', defaultValue: false)
    required bool theyBlockedMe,
  }) = _RelationshipStatusDto;

  factory RelationshipStatusDto.fromJson(Map<String, dynamic> json) =>
      _$RelationshipStatusDtoFromJson(json);

  RelationshipStatusEntity toEntity() => RelationshipStatusEntity(
        userId: userId,
        iBlockedThem: iBlockedThem,
        iFollowThem: iFollowThem,
        iRestrictedThem: iRestrictedThem,
        theyFollowMe: theyFollowMe,
        theyBlockedMe: theyBlockedMe,
      );
}
