import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/data/models/author_info_dto.dart';
import 'package:app/src/features/home/domain/entities/seal_response_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'seal_response_dto.freezed.dart';
part 'seal_response_dto.g.dart';

@freezed
class SealResponseDto extends BaseDto with _$SealResponseDto {
  const SealResponseDto._();

  const factory SealResponseDto({
    required AuthorInfoDto user,
    required int amount,
    String? comment,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _SealResponseDto;

  factory SealResponseDto.fromJson(Map<String, dynamic> json) =>
      _$SealResponseDtoFromJson(json);

  SealResponseEntity toEntity() => SealResponseEntity(
        user: user.toEntity(),
        amount: amount,
        comment: comment ?? '',
        createdAt: createdAt,
      );
}
