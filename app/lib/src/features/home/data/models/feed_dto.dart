import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/data/models/post_response_dto.dart';
import 'package:app/src/features/home/domain/entities/feed_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'feed_dto.freezed.dart';
part 'feed_dto.g.dart';

@freezed
class FeedDto extends BaseDto with _$FeedDto {
  const FeedDto._();
  const factory FeedDto({
    List<PostResponseDto>? items,
    @JsonKey(name: 'next_cursor') String? nextCursor,
  }) = _FeedDto;

  factory FeedDto.fromJson(Map<String, dynamic> json) =>
      _$FeedDtoFromJson(json);

  FeedEntity toEntity() => FeedEntity(
        items: (items ?? const <PostResponseDto>[])
            .map((e) => e.toEntity())
            .toList(),
        nextCursor: nextCursor ?? '',
      );
}
