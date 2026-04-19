import 'package:app/src/features/home/domain/entities/author_info_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'interaction_response_entity.freezed.dart';
part 'interaction_response_entity.g.dart';

@freezed
class InteractionResponseEntity with _$InteractionResponseEntity {
  const factory InteractionResponseEntity({
    required AuthorInfoEntity user,
    required String createdAt,
  }) = _InteractionResponseEntity;

  const factory InteractionResponseEntity.empty({
    @Default(AuthorInfoEntity.empty()) AuthorInfoEntity user,
    @Default('') String createdAt,
  }) = _InteractionResponseEntityEmpty;

  factory InteractionResponseEntity.fromJson(Map<String, dynamic> json) =>
      _$InteractionResponseEntityFromJson(json);
}
