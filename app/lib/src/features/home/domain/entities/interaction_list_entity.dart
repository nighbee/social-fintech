import 'package:app/src/features/home/domain/entities/interaction_response_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'interaction_list_entity.freezed.dart';
part 'interaction_list_entity.g.dart';

@freezed
class InteractionListEntity with _$InteractionListEntity {
  const factory InteractionListEntity({
    required List<InteractionResponseEntity> items,
    @Default('') String nextCursor,
  }) = _InteractionListEntity;

  const factory InteractionListEntity.empty({
    @Default([]) List<InteractionResponseEntity> items,
    @Default('') String nextCursor,
  }) = _InteractionListEntityEmpty;

  factory InteractionListEntity.fromJson(Map<String, dynamic> json) =>
      _$InteractionListEntityFromJson(json);
}
