import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/profile.dart';

part 'relationship_dto.freezed.dart';
part 'relationship_dto.g.dart';

@freezed
class RelationshipDto with _$RelationshipDto {
  const factory RelationshipDto({
    required String id,
    @JsonKey(name: 'target_user_id') required String targetUserId,
    @JsonKey(name: 'target_username') required String targetUsername,
    @JsonKey(name: 'target_display_name') String? targetDisplayName,
    @JsonKey(name: 'target_avatar_url') String? targetAvatarUrl,
    @JsonKey(name: 'relationship_type') required String relationshipType,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _RelationshipDto;

  const RelationshipDto._();

  factory RelationshipDto.fromJson(Map<String, dynamic> json) =>
      _$RelationshipDtoFromJson(json);

  RelationshipResponse toDomain() {
    return RelationshipResponse(
      id: id,
      targetUserId: targetUserId,
      targetUsername: targetUsername,
      targetDisplayName: targetDisplayName,
      targetAvatarUrl: targetAvatarUrl ?? '',
      relationshipType: _parseRelationshipType(relationshipType),
      createdAt: createdAt,
    );
  }

  RelationshipType _parseRelationshipType(String type) {
    switch (type.toLowerCase()) {
      case 'ally':
        return RelationshipType.ally;
      case 'favorite':
        return RelationshipType.favorite;
      case 'block':
        return RelationshipType.block;
      case 'restrict':
        return RelationshipType.restrict;
      default:
        return RelationshipType.ally;
    }
  }
}
