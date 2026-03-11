import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/data/models/interaction_response_dto.dart';
import 'package:app/src/features/home/domain/entities/interaction_list_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'interaction_list_dto.freezed.dart';
part 'interaction_list_dto.g.dart';

@freezed
class InteractionListDto extends BaseDto with _$InteractionListDto {
  const InteractionListDto._();
  const factory InteractionListDto({
    required List<InteractionResponseDto> items,
    @JsonKey(name: 'next_cursor') String? nextCursor,
  }) = _InteractionListDto;

  factory InteractionListDto.fromJson(Map<String, dynamic> json) =>
      _$InteractionListDtoFromJson(json);

  InteractionListEntity toEntity() => InteractionListEntity(
        items: items.map((e) => e.toEntity()).toList(),
        nextCursor: nextCursor ?? '',
      );
}
