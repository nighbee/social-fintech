import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/data/models/seal_response_dto.dart';
import 'package:app/src/features/home/domain/entities/seal_list_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'seal_list_dto.freezed.dart';
part 'seal_list_dto.g.dart';

@freezed
class SealListDto extends BaseDto with _$SealListDto {
  const SealListDto._();

  const factory SealListDto({
    required List<SealResponseDto> items,
    @JsonKey(name: 'next_cursor') String? nextCursor,
  }) = _SealListDto;

  factory SealListDto.fromJson(Map<String, dynamic> json) =>
      _$SealListDtoFromJson(json);

  SealListEntity toEntity() => SealListEntity(
        items: items.map((item) => item.toEntity()).toList(),
        nextCursor: nextCursor ?? '',
      );
}
