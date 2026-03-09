import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/data/models/author_info_dto.dart';
import 'package:app/src/features/home/domain/entities/interaction_response_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'interaction_response_dto.freezed.dart';
part 'interaction_response_dto.g.dart';

@freezed
class InteractionResponseDto extends BaseDto with _$InteractionResponseDto {
  const InteractionResponseDto._();
  const factory InteractionResponseDto({
    required AuthorInfoDto user,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _InteractionResponseDto;

  factory InteractionResponseDto.fromJson(Map<String, dynamic> json) =>
      _$InteractionResponseDtoFromJson(json);

  InteractionResponseEntity toEntity() => InteractionResponseEntity(
        user: user.toEntity(),
        createdAt: createdAt,
      );
}
