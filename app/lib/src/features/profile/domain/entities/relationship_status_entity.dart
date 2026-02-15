import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:app/src/core/base/base_models/base_entity.dart';

part 'relationship_status_entity.freezed.dart';
part 'relationship_status_entity.g.dart';

@freezed
class RelationshipStatusEntity extends BaseEntity
    with _$RelationshipStatusEntity {
  const factory RelationshipStatusEntity({
    required String userId,
    required bool iBlockedThem,
    required bool iFollowThem,
    required bool iRestrictedThem,
    required bool theyFollowMe,
  }) = _RelationshipStatusEntity;

  const factory RelationshipStatusEntity.empty({
    @Default('') String userId,
    @Default(false) bool iBlockedThem,
    @Default(false) bool iFollowThem,
    @Default(false) bool iRestrictedThem,
    @Default(false) bool theyFollowMe,
  }) = _RelationshipStatusEntityEmpty;

  factory RelationshipStatusEntity.fromJson(Map<String, dynamic> json) =>
      _$RelationshipStatusEntityFromJson(json);
}
